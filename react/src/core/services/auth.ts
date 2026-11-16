// Port of lib/core/services/auth_service.dart — the parts the gateway needs.
// Still to port when their features move: XP setup, letterbox seeding,
// push-notification sync, partner lookup, logout cleanup.
import { onAuthStateChanged, signInWithCustomToken, signOut, type User } from 'firebase/auth';
import { doc, serverTimestamp, setDoc } from 'firebase/firestore';
import { useSyncExternalStore } from 'react';
import { AgentMode } from '../agent/agentMode';
import { RouteMemory } from '../router/routeMemory';
import { Logger } from '../system/logger';
import { Prefs } from '../system/prefs';
import { auth, db } from './firebase';

export class PasscodeConnectionError extends Error {}

type OfflineVerifier = { username: string; salt: string; digest: string };

const COUPLE = new Set(['khentsgdz', 'clairjassen']);

async function sha256Hex(text: string): Promise<string> {
  const bytes = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(text));
  return [...new Uint8Array(bytes)].map((b) => b.toString(16).padStart(2, '0')).join('');
}

function base64Url(bytes: Uint8Array): string {
  return btoa(String.fromCharCode(...bytes)).replace(/\+/g, '-').replace(/\//g, '_');
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
          void signOut(auth);
        } else {
          void this.syncUserDoc();
        }
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
    const urls = [
      ...(isLocal ? [] : ['/api/verifyPasscode']),
      'https://us-central1-everglow-1c6db.cloudfunctions.net/verifyPasscode',
      'https://everglow-1c6db.web.app/api/verifyPasscode',
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
    if (!v.salt || (await sha256Hex(`${remembered}:${v.salt}:${passcode}`)) !== v.digest) return null;
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
    this.offlineVerifier = { username: name, salt, digest: await sha256Hex(`${name}:${salt}:${passcode}`) };
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
    } catch (e) {
      this.hasSyncedUserDoc = false;
      Logger.e(`[AuthService] syncUserDoc failed for ${this.currentUser}`, e);
    }
  }

  async logout() {
    this.isAgentSession = false;
    this.lastAuthError = null;
    try {
      await signOut(auth);
    } catch (e) {
      Logger.w(`signOut warning: ${String(e)}`);
    }
    RouteMemory.clear();
    this.currentUser = null;
    this.user = null;
    this.partnerUid = null;
    this.partnerNameResolved = null;
    this.hasSyncedUserDoc = false;
    this.isOfflineMode = false;
    await this.saveSession(null, null);
    AgentMode.clearPersistedState();
    this.notify();
  }
}

export const authService = new AuthService();

/** Re-renders when the session changes (like `context.watch<AuthService>()`). */
export function useAuth(): AuthService {
  useSyncExternalStore(authService.subscribe, authService.getVersion);
  return authService;
}
