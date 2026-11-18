// Port of lib/core/services/notification_service.dart.
import { deleteDoc, doc, serverTimestamp, setDoc } from 'firebase/firestore';
import { deleteToken, getMessaging, getToken, isSupported, onMessage, type Messaging } from 'firebase/messaging';
import { AgentMode } from '../agent/agentMode';
import { Logger } from '../system/logger';
import { Prefs } from '../system/prefs';
import { app, auth, db } from './firebase';

const COUPLE = new Set(['khentsgdz', 'clairjassen']);
const TOKEN_STORAGE_KEY = 'fcm_device_token';
const DEFAULT_VAPID_KEY =
  'BL2l-ngjWKYYXNK5QKHRcLt4zUyHq-3wTgY5NO0MOcGEoI03Eh3A3Kk2us_hQdN4tXyOO4A6ldQ1T5L7DLTSrT0';

export function routeFromNotification(data: Record<string, string> | undefined): string | null {
  switch (data?.type) {
    case 'chat_message':
      return '/sanctuary';
    case 'mood_update':
    case 'milestone':
    case 'special_day':
    case 'special_day_upcoming':
    case 'mood_checkin':
    case 'watch_party_invite':
      return '/dashboard';
    case 'starlight_drop':
      return '/starlight';
    case 'watchlist_update':
      return '/cinema';
    case 'motchi_note':
      return '/motchi';
    case 'daily_digest':
    case 'night_recap':
      return '/motchi-today';
    case 'gallery_photo':
      return '/gallery';
    default:
      return null;
  }
}

export type PushIdentity = { username: string; uid: string };
export type ForegroundNotification = {
  title: string;
  body: string;
  route: string | null;
};

async function sha256Hex(text: string): Promise<string> {
  const bytes = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(text));
  return [...new Uint8Array(bytes)].map((b) => b.toString(16).padStart(2, '0')).join('');
}

class NotificationService {
  private messaging: Messaging | null = null;
  private activeIdentity: PushIdentity | null = null;
  private registeredIdentity: PushIdentity | null = null;
  private registeredToken: string | null = null;
  private permissionGranted = false;
  private sessionGeneration = 0;
  private listenersStarted = false;
  private operations: Promise<void> = Promise.resolve();
  private onForeground: ((n: ForegroundNotification) => void) | null = null;

  setForegroundHandler(fn: ((n: ForegroundNotification) => void) | null): void {
    this.onForeground = fn;
  }

  private async ensureMessaging(): Promise<Messaging | null> {
    if (this.messaging) return this.messaging;
    if (AgentMode.demo) return null;
    try {
      if (!(await isSupported())) return null;
      this.messaging = getMessaging(app);
      return this.messaging;
    } catch (e) {
      Logger.e('FCM init skipped', e);
      return null;
    }
  }

  async initialize(): Promise<void> {
    const msg = await this.ensureMessaging();
    if (!msg) return;
    if (!this.listenersStarted) {
      this.listenersStarted = true;
      try {
        onMessage(msg, (payload) => {
          if (!this.hasActiveCoupleSession) return;
          const title = payload.notification?.title ?? '';
          const body = payload.notification?.body ?? '';
          if (!title && !body) return;
          const route = routeFromNotification(payload.data);
          this.onForeground?.({ title, body, route });
        });
      } catch (e) {
        Logger.e('FCM listener setup failed', e);
      }
    }
    try {
      if (typeof Notification !== 'undefined') {
        if (Notification.permission === 'granted') {
          this.permissionGranted = true;
        } else if (Notification.permission === 'default') {
          const perm = await Notification.requestPermission();
          this.permissionGranted = perm === 'granted';
        }
      }
    } catch (e) {
      Logger.e('FCM requestPermission failed', e);
      return;
    }
    if (this.permissionGranted && this.activeIdentity != null) {
      await this.syncAuthSession(true);
    }
  }

  private get hasActiveCoupleSession(): boolean {
    const id = this.activeIdentity;
    return id != null && auth.currentUser?.uid === id.uid;
  }

  private async verifiedIdentity(): Promise<PushIdentity | null> {
    if (AgentMode.demo) return null;
    const user = auth.currentUser;
    if (!user) return null;
    const result = await user.getIdTokenResult();
    const firebase = result.claims['firebase'] as Record<string, unknown> | undefined;
    const username = result.claims['username'];
    if (
      !firebase ||
      firebase['sign_in_provider'] !== 'custom' ||
      typeof username !== 'string' ||
      !COUPLE.has(username) ||
      auth.currentUser?.uid !== user.uid
    ) {
      return null;
    }
    return { username, uid: user.uid };
  }

  private isCurrent(generation: number, id: PushIdentity): boolean {
    return (
      generation === this.sessionGeneration &&
      this.activeIdentity?.uid === id.uid &&
      this.activeIdentity?.username === id.username &&
      auth.currentUser?.uid === id.uid
    );
  }

  private enqueue(op: () => Promise<void>): Promise<void> {
    const next = this.operations.then(op);
    this.operations = next.catch((e) => {
      Logger.e('FCM token operation failed', e);
    });
    return next;
  }

  private async getFcmToken(): Promise<string | null> {
    const msg = await this.ensureMessaging();
    if (!msg) return null;
    const vapidKey = (import.meta.env.VITE_FCM_VAPID_KEY as string | undefined) || DEFAULT_VAPID_KEY;
    const swReg =
      'serviceWorker' in navigator
        ? await navigator.serviceWorker.ready.catch(() => undefined)
        : undefined;
    try {
      const token = await getToken(msg, {
        vapidKey,
        ...(swReg ? { serviceWorkerRegistration: swReg } : {}),
      });
      return token || null;
    } catch (e) {
      Logger.e('FCM getToken failed', e);
      return null;
    }
  }

  private async deviceDoc(username: string, token: string) {
    const hash = await sha256Hex(token);
    return doc(db, 'fcm_tokens', username, 'devices', hash);
  }

  private async writeToken(id: PushIdentity, token: string): Promise<void> {
    const ref = await this.deviceDoc(id.username, token);
    await setDoc(
      ref,
      {
        token,
        uid: id.uid,
        updatedAt: serverTimestamp(),
        platform: 'TargetPlatform.web',
      },
      { merge: true },
    );
  }

  private async removeToken(username: string, token: string): Promise<void> {
    const ref = await this.deviceDoc(username, token);
    await deleteDoc(ref);
  }

  private async registerToken(id: PushIdentity, token: string, generation: number): Promise<void> {
    if (
      this.registeredIdentity &&
      this.registeredToken &&
      (this.registeredIdentity.username !== id.username || this.registeredToken !== token)
    ) {
      await this.removeToken(this.registeredIdentity.username, this.registeredToken);
      this.registeredIdentity = null;
      this.registeredToken = null;
    }
    if (!this.isCurrent(generation, id)) return;
    Prefs.set(TOKEN_STORAGE_KEY, token);
    await this.writeToken(id, token);
    if (!this.isCurrent(generation, id)) return;
    this.registeredIdentity = id;
    this.registeredToken = token;
  }

  private async removeRegisteredDevice(fallback: PushIdentity | null): Promise<void> {
    const id = this.registeredIdentity ?? fallback;
    if (!id) return;
    const token = this.registeredToken ?? Prefs.getString(TOKEN_STORAGE_KEY);
    if (!token) return;
    await this.removeToken(id.username, token);
    if (this.registeredIdentity?.username === id.username && this.registeredToken === token) {
      this.registeredIdentity = null;
      this.registeredToken = null;
    }
  }

  async syncAuthSession(enabled: boolean): Promise<void> {
    const generation = ++this.sessionGeneration;
    let identity: PushIdentity | null = null;
    try {
      if (enabled) identity = await this.verifiedIdentity();
    } catch (e) {
      Logger.e('FCM auth identity check failed', e);
    }
    if (generation !== this.sessionGeneration) return;

    const previous = this.activeIdentity;
    this.activeIdentity = identity;
    try {
      await this.enqueue(async () => {
        if (!identity) {
          await this.removeRegisteredDevice(previous);
          return;
        }
        if (this.registeredIdentity && this.registeredIdentity.username !== identity.username) {
          await this.removeRegisteredDevice(this.registeredIdentity);
        }
        if (!this.isCurrent(generation, identity) || !this.permissionGranted) return;
        const token = await this.getFcmToken();
        if (!token || !this.isCurrent(generation, identity)) return;
        await this.registerToken(identity, token, generation);
      });
    } catch (e) {
      Logger.e('FCM device registration failed', e);
    }
  }

  async unregisterForLogout(): Promise<void> {
    this.sessionGeneration++;
    const previous = this.activeIdentity;
    this.activeIdentity = null;
    await this.enqueue(async () => {
      const id = this.registeredIdentity ?? previous ?? (await this.verifiedIdentity());
      const token = id ? (this.registeredToken ?? Prefs.getString(TOKEN_STORAGE_KEY)) : null;
      if (id && token) {
        await this.removeToken(id.username, token);
        const msg = await this.ensureMessaging();
        if (msg) await deleteToken(msg).catch(() => {});
        Prefs.remove(TOKEN_STORAGE_KEY);
      }
      this.registeredIdentity = null;
      this.registeredToken = null;
    });
  }
}

export const notificationService = new NotificationService();
