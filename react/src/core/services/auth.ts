// Port of lib/core/services/auth_service.dart — the parts the gateway needs.
// Still to port when their features move: XP setup, letterbox seeding,
// push-notification sync, partner lookup, logout cleanup.
import { OfflinePhotos } from '../../features/gallery/offlinePhotos';
import { onAuthStateChanged, signInWithCustomToken, signOut, type User } from 'firebase/auth';
import {
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocFromCache,
  getDocs,
  getDocsFromCache,
  limit,
  query,
  serverTimestamp,
  setDoc,
  Timestamp,
  where,
  type DocumentData,
} from 'firebase/firestore';
import { useSyncExternalStore } from 'react';
import { AgentMode } from '../agent/agentMode';
import { RouteMemory } from '../router/routeMemory';
import { Logger } from '../system/logger';
import { presenceService } from './presence';
import { Prefs } from '../system/prefs';
import { withGetTimeout } from '../utils/liveSource';
import { initializeProgress } from '../../features/xp/xpService';
import { letterboxService } from '../../features/dashboard/letterboxService';
import { auth, clearFirestoreCache, db } from './firebase';
import { notificationService } from './notifications';

export class PasscodeConnectionError extends Error {}

type OfflineVerifier = { v?: number; username: string; salt: string; digest: string };

const COUPLE = new Set(['khentsgdz', 'clairjassen']);
const PBKDF2_ITERATIONS = 310_000;

async function sha256Hex(text: string): Promise<string> {
  const bytes = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(text));
  return [...new Uint8Array(bytes)].map((b) => b.toString(16).padStart(2, '0')).join('');
}

async function pbkdf2Hex(username: string, salt: string, passcode: string): Promise<string> {
  const enc = new TextEncoder();
  const key = await crypto.subtle.importKey('raw', enc.encode(`${username}:${passcode}`), 'PBKDF2', false, [
    'deriveBits',
  ]);
  const bits = await crypto.subtle.deriveBits(
    { name: 'PBKDF2', salt: enc.encode(salt), iterations: PBKDF2_ITERATIONS, hash: 'SHA-256' },
    key,
    256,
  );
  return [...new Uint8Array(bits)].map((b) => b.toString(16).padStart(2, '0')).join('');
}

function base64Url(bytes: Uint8Array): string {
  return btoa(String.fromCharCode(...bytes))
    .replace(/\+/g, '-')
    .replace(/\//g, '_');
}

class AuthService {
  user: User | null = null;
  currentUser: string | null = null;
  lastAuthError: string | null = null;
  isSessionLoaded = false;
  isAgentSession = false;
  isOfflineMode = false;
  partnerUid: string | null = null;
  private partnerNameResolved: string | null = null;
  private offlineVerifier: OfflineVerifier | null = null;
  private hasSyncedUserDoc = false;
  isResolvingPartner = false;
  private listeners = new Set<() => void>();
  private version = 0;

  constructor() {
    this.loadSession();
    onAuthStateChanged(auth, (user) => {
      this.user = user;
      this.hasSyncedUserDoc = false;
      if (user && this.currentUser != null) {
        if (user.isAnonymous && this.isCoupleUser) {
          Logger.e(`[AuthService] clearing anonymous session for couple user ${this.currentUser} — real login required`);
          void notificationService.syncAuthSession(false);
          void signOut(auth);
        } else {
          void this.syncUserDoc();
        }
      } else {
        void notificationService.syncAuthSession(false);
      }
      this.notify();
    });
  }

  get isCoupleUser(): boolean {
    return this.currentUser != null && COUPLE.has(this.currentUser);
  }

  get isCinemaOnlyUser(): boolean {
    return this.currentUser === 'breyan' || this.currentUser === 'octagram';
  }

  get isAnonymousSession(): boolean {
    return !this.isAgentSession && auth.currentUser?.isAnonymous === true;
  }

  get isAuthenticated(): boolean {
    return this.user != null || this.isAgentSession;
  }

  get hasOfflineRememberedCode(): boolean {
    return this.isCoupleUser && this.offlineVerifier?.username === this.currentUser;
  }

  get uid(): string | null {
    return this.isAgentSession ? `agent_${this.currentUser}_uid` : (auth.currentUser?.uid ?? null);
  }

  get isReady(): boolean {
    return this.currentUser != null && (this.user != null || this.isOfflineMode);
  }

  get partnerName(): string {
    return this.partnerNameResolved ?? 'Partner';
  }

  get partnerUsername(): string | null {
    if (this.currentUser === 'clairjassen') return 'khentsgdz';
    if (this.currentUser === 'khentsgdz') return 'clairjassen';
    return null;
  }

  subscribe = (l: () => void) => {
    this.listeners.add(l);
    return () => this.listeners.delete(l);
  };

  getVersion = () => this.version;

  private notify() {
    this.version++;
    for (const l of this.listeners) l();
  }

  private loadSession() {
    if (this.isAgentSession) return;
    this.currentUser = Prefs.getString('current_user_name');
    const saved = Prefs.getString('offline_passcode_verifier');
    if (saved) {
      try {
        this.offlineVerifier = JSON.parse(saved) as OfflineVerifier;
      } catch (e) {
        Logger.e('Failed to read offline verifier', e);
      }
    }
    if (this.currentUser) Logger.i(`Restored session for: ${this.currentUser}`);
    this.isSessionLoaded = true;
    this.notify();
  }

  enableAgentSession(profile = 'khentsgdz') {
    if (!AgentMode.canActivate) return;
    if (this.isAgentSession && this.currentUser === profile) return;
    this.isAgentSession = true;
    this.currentUser = profile;
    this.isOfflineMode = true;
    this.isSessionLoaded = true;
    this.lastAuthError = null;
    if (profile === 'breyan' || profile === 'octagram') {
      this.partnerUid = null;
      this.partnerNameResolved = null;
    } else {
      this.partnerUid = 'agent_demo_partner_uid';
      this.partnerNameResolved = profile === 'khentsgdz' ? 'Clair' : 'Khent';
    }
    Logger.i(`[AuthService] Agent session enabled as ${profile}`);
    this.notify();
  }

  async ensureAuthenticated(): Promise<void> {
    if (auth.currentUser == null && !this.isAgentSession) {
      Logger.e('Authentication required; anonymous fallback is disabled by security rules.');
    }
  }

  /** Returns the username, null for a wrong code, or throws when unreachable. */
  async verifyCouplePasscode(passcode: string): Promise<string | null> {
    const host = window.location.hostname;
    const isLocal = host === 'localhost' || host === '127.0.0.1' || host === '0.0.0.0';
    const isProdOrigin = window.location.origin === 'https://everglow-1c6db.web.app';
    const urls = [
      ...(isLocal ? [] : ['/api/verifyPasscode']),
      'https://us-central1-everglow-1c6db.cloudfunctions.net/verifyPasscode',
      ...(isProdOrigin ? [] : ['https://everglow-1c6db.web.app/api/verifyPasscode']),
    ];
    let lastError: unknown = null;
    for (const url of urls) {
      try {
        const resp = await fetch(url, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ passcode }),
          signal: AbortSignal.timeout(10_000),
        });
        if (resp.status === 401 || resp.status === 400) return null;
        if (resp.status === 429) {
          throw new PasscodeConnectionError('HTTP 429');
        }
        if (resp.status !== 200) {
          lastError = `HTTP ${resp.status}`;
          Logger.e(`verifyCouplePasscode ${url} -> ${resp.status}`);
          continue;
        }
        const data = (await resp.json()) as { token?: string; username?: string };
        if (!data.token || !data.username) {
          lastError = 'missing token/username';
          Logger.e(`verifyCouplePasscode missing token/username from ${url}`);
          continue;
        }
        try {
          await signInWithCustomToken(auth, data.token);
        } catch (e) {
          lastError = e;
          Logger.e(`verifyCouplePasscode sign-in failed via ${url}`, e);
          continue;
        }
        this.currentUser = data.username;
        this.isAgentSession = false;
        await this.saveSession(data.username, this.isCoupleUser ? passcode : null);
        void this.syncUserDoc();
        this.lastAuthError = null;
        this.isOfflineMode = false;
        this.notify();
        return data.username;
      } catch (e) {
        if (e instanceof PasscodeConnectionError) throw e;
        lastError = e;
        Logger.e(`verifyCouplePasscode ${url} failed`, e);
      }
    }
    throw new PasscodeConnectionError(String(lastError));
  }

  async tryOfflineRememberedLogin(passcode: string): Promise<string | null> {
    const remembered = this.currentUser;
    const v = this.offlineVerifier;
    if (!remembered || !COUPLE.has(remembered) || !/^\d{4}$/.test(passcode) || v?.username !== remembered) {
      return null;
    }
    if (!v.salt) return null;
    if (v.v === 2) {
      if ((await pbkdf2Hex(remembered, v.salt, passcode)) !== v.digest) return null;
    } else {
      if ((await sha256Hex(`${remembered}:${v.salt}:${passcode}`)) !== v.digest) return null;
      await this.saveSession(remembered, passcode);
    }
    this.isOfflineMode = true;
    this.lastAuthError = null;
    Logger.i(`[AuthService] offline remembered login for ${remembered}`);
    this.notify();
    return remembered;
  }

  private async saveSession(name: string | null, passcode: string | null) {
    if (name) Prefs.set('current_user_name', name);
    else Prefs.remove('current_user_name');
    if (!name || !passcode) {
      this.offlineVerifier = null;
      Prefs.remove('offline_passcode_verifier');
      return;
    }
    const salt = base64Url(crypto.getRandomValues(new Uint8Array(32)));
    this.offlineVerifier = { v: 2, username: name, salt, digest: await pbkdf2Hex(name, salt, passcode) };
    Prefs.set('offline_passcode_verifier', JSON.stringify(this.offlineVerifier));
  }

  private async syncUserDoc() {
    if (this.isAgentSession || this.hasSyncedUserDoc) return;
    const me = auth.currentUser;
    if (!me || !this.currentUser) return;
    this.hasSyncedUserDoc = true;
    try {
      const identity = await me.getIdTokenResult();
      if (identity.signInProvider === 'password' && this.isCinemaOnlyUser) {
        this.currentUser = null;
        this.user = null;
        this.hasSyncedUserDoc = false;
        await this.saveSession(null, null);
        await signOut(auth);
        this.notify();
        return;
      }
      if (identity.claims['username'] !== this.currentUser) {
        this.hasSyncedUserDoc = false;
        return;
      }
      await setDoc(
        doc(db, 'users', me.uid),
        { username: this.currentUser, partnerUsername: this.partnerUsername, updatedAt: serverTimestamp() },
        { merge: true },
      );
      Logger.i(`[AuthService] users doc synced for ${this.currentUser} (${me.uid})`);
      void Promise.all([
        this.resolvePartnerInfo().catch((e) => Logger.e('AuthService._resolvePartnerInfo failed (bg)', e)),
        initializeProgress(me.uid).catch((e) => Logger.e('XP init failed (bg)', e)),
        ...(this.isCoupleUser
          ? [
              letterboxService.ensureSeeded().catch((e) => Logger.e('Letterbox seed failed (bg)', e)),
              notificationService.syncAuthSession(true).catch((e) => Logger.e('FCM sync failed (bg)', e)),
            ]
          : []),
      ]);
    } catch (e) {
      let repaired = false;
      try {
        repaired = await this.repairStaleUserDoc(me.uid);
      } catch (e2) {
        Logger.e(`[AuthService] users doc repair failed for ${this.currentUser} (${me.uid})`, e2);
      }
      if (!repaired) {
        this.hasSyncedUserDoc = false;
        Logger.e(`[AuthService] _syncUserDoc failed for ${this.currentUser} (${me.uid})`, e);
      }
    }
  }

  private async repairStaleUserDoc(myUid: string): Promise<boolean> {
    const ref = doc(db, 'users', myUid);
    const snap = await getDocFast(ref, 'auth stale user-doc check');
    if (!snap.exists()) return false;
    if (!needsUserDocRepair(snap.data() ?? {}, this.currentUser)) return false;
    Logger.i(`[AuthService] repairing stale users doc for ${this.currentUser} (${myUid})`);
    await deleteDoc(ref);
    await setDoc(
      ref,
      { username: this.currentUser, partnerUsername: this.partnerUsername, updatedAt: serverTimestamp() },
      { merge: true },
    );
    Logger.i(`[AuthService] users doc repaired for ${this.currentUser} (${myUid})`);
    return true;
  }

  refreshPartnerLink(): Promise<void> {
    return this.resolvePartnerInfo();
  }

  private async resolvePartnerInfo(): Promise<void> {
    if (this.isAgentSession || this.isResolvingPartner) return;
    const me = auth.currentUser;
    if (this.currentUser == null || me == null) return;
    this.isResolvingPartner = true;
    this.notify();
    try {
      let partnerUser = this.partnerUsername;
      try {
        const own = await getDocFast(doc(db, 'users', me.uid), 'auth own user-doc read');
        const stored = own.data()?.['partnerUsername'];
        if (typeof stored === 'string' && stored !== '') partnerUser = stored;
      } catch (e) {
        Logger.e('AuthService._resolvePartnerInfo own doc read failed', e);
      }
      if (partnerUser == null) {
        this.partnerUid = null;
        this.partnerNameResolved = null;
        return;
      }
      try {
        const q = query(collection(db, 'users'), where('username', '==', partnerUser), limit(10));
        const snap = await getQueryFast(q, 'auth partner lookup');
        const uid = pickPartnerUid(
          snap.docs.map((d) => ({ id: d.id, data: d.data() as DocumentData })),
          this.currentUser,
        );
        if (uid != null) {
          this.partnerUid = uid;
          this.partnerNameResolved = partnerUser === 'khentsgdz' ? 'Khent' : 'Clair';
        } else {
          this.partnerUid = null;
          this.partnerNameResolved = null;
        }
      } catch (e) {
        Logger.e('AuthService._resolvePartnerInfo failed', e);
      }
    } finally {
      this.isResolvingPartner = false;
      this.notify();
    }
  }

  async logout() {
    const wasAgent = this.isAgentSession;
    this.isAgentSession = false;
    this.lastAuthError = null;
    try {
      await presenceService.stopHeartbeat();
    } catch (e) {
      Logger.w(`Presence logout cleanup warning: ${String(e)}`);
    }
    try {
      await notificationService.unregisterForLogout();
    } catch (e) {
      Logger.w(`FCM logout cleanup warning: ${String(e)}`);
    }
    try {
      await signOut(auth);
    } catch (e) {
      Logger.w(`signOut warning: ${String(e)}`);
    }
    RouteMemory.clear();
    Prefs.remove('spotify_code_verifier');
    Prefs.remove('spotify_oauth_state');
    this.currentUser = null;
    this.user = null;
    this.partnerUid = null;
    this.partnerNameResolved = null;
    this.hasSyncedUserDoc = false;
    this.isOfflineMode = false;
    await this.saveSession(null, null);
    AgentMode.clearPersistedState();
    await OfflinePhotos.clear();
    if (!wasAgent) {
      await clearFirestoreCache();
    }
    this.notify();
    if (!wasAgent && typeof window !== 'undefined') {
      window.location.replace('/');
    }
  }
}

async function getDocFast(ref: ReturnType<typeof doc>, label: string) {
  try {
    const cached = await getDocFromCache(ref);
    if (cached.exists()) return cached;
  } catch (e) {
    Logger.d(`getDocFast cache miss for ${label}: ${String(e)}`);
  }
  return withGetTimeout(getDoc(ref), label);
}

async function getQueryFast(q: ReturnType<typeof query>, label: string) {
  try {
    const cached = await getDocsFromCache(q);
    if (!cached.empty) return cached;
  } catch (e) {
    Logger.d(`getQueryFast cache miss for ${label}: ${String(e)}`);
  }
  return withGetTimeout(getDocs(q), label);
}

export function needsUserDocRepair(data: DocumentData, currentUser: string | null): boolean {
  const allowed = new Set(['username', 'partnerUsername', 'updatedAt', 'createdAt']);
  if (data['username'] !== currentUser) return true;
  return !Object.keys(data).every((k) => allowed.has(k));
}

function docUpdatedAt(data: DocumentData): number {
  const v = data['updatedAt'];
  if (v instanceof Timestamp) return v.toMillis();
  if (v instanceof Date) return v.getTime();
  if (typeof v === 'number') return v;
  if (typeof v === 'string') {
    const t = Date.parse(v);
    if (!Number.isNaN(t)) return t;
  }
  return 0;
}

/** AuthService.pickPartnerUid: the doc that links back to me wins, then the newest, then the smallest id. */
export function pickPartnerUid(docs: { id: string; data: DocumentData }[], myUsername: string | null): string | null {
  if (docs.length === 0) return null;
  const linksBack = (d: DocumentData) => myUsername != null && myUsername !== '' && d['partnerUsername'] === myUsername;
  const ranked = [...docs].sort((a, b) => {
    const al = linksBack(a.data);
    const bl = linksBack(b.data);
    if (al !== bl) return al ? -1 : 1;
    const byUpdated = docUpdatedAt(b.data) - docUpdatedAt(a.data);
    if (byUpdated !== 0) return byUpdated;
    return a.id < b.id ? -1 : a.id > b.id ? 1 : 0;
  });
  return ranked[0].id;
}

export const authService = new AuthService();

/** Re-renders when the session changes (like `context.watch<AuthService>()`). */
export function useAuth(): AuthService {
  useSyncExternalStore(authService.subscribe, authService.getVersion);
  return authService;
}
