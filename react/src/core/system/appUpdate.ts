// Port of lib/core/system/app_update_service.dart.
import { useSyncExternalStore } from 'react';
import { Logger } from './logger';

export type LiveBuild = { build: string; core?: string | null };

const POLL_INTERVAL_MS = 15 * 60_000;
const FETCH_TIMEOUT_MS = 10_000;
const WARM_TIMEOUT_MS = 150_000;

class AppUpdateService {
  private started = false;
  private checking = false;
  private warming = false;
  private ready = false;
  private applied = false;
  private bootBuild: string | null = null;
  private latestBuild: string | null = null;
  private dismissedBuild: string | null = null;
  private pollTimer: number | null = null;
  private cleanupListeners: (() => void) | null = null;
  private listeners = new Set<() => void>();
  private version = 0;

  get updateAvailable(): boolean {
    return this.ready && !this.isDismissed && !this.applied;
  }

  get isDismissed(): boolean {
    return this.dismissedBuild != null && this.dismissedBuild === this.latestBuild;
  }

  get currentLatestBuild(): string | null {
    return this.latestBuild;
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

  start(): void {
    if (this.started || typeof window === 'undefined') return;
    this.started = true;
    const onVisibility = () => {
      if (document.visibilityState === 'visible') {
        void this.checkNow();
      }
    };
    const onOnline = () => void this.checkNow();
    document.addEventListener('visibilitychange', onVisibility);
    window.addEventListener('online', onOnline);
    this.cleanupListeners = () => {
      document.removeEventListener('visibilitychange', onVisibility);
      window.removeEventListener('online', onOnline);
    };
    void this.checkNow();
    this.pollTimer = window.setInterval(() => void this.checkNow(), POLL_INTERVAL_MS);
  }

  async checkNow(): Promise<void> {
    if (this.checking || this.applied || !navigator.onLine) return;
    this.checking = true;
    try {
      const live = await this.fetchLiveBuild();
      await this.noteLiveBuild(live?.build ?? null, live?.core ?? null);
    } finally {
      this.checking = false;
    }
  }

  async fetchLiveBuild(): Promise<LiveBuild | null> {
    if (!navigator.onLine) return null;
    try {
      const res = await fetch(`/version.json?t=${Date.now()}`, {
        cache: 'no-store',
        signal: AbortSignal.timeout(FETCH_TIMEOUT_MS),
      });
      if (!res.ok) return null;
      const body = (await res.json()) as Record<string, unknown>;
      const build = typeof body.build === 'string' && body.build ? body.build : null;
      if (!build) return null;
      const core = typeof body.core === 'string' && body.core ? body.core : null;
      return { build, core };
    } catch {
      return null;
    }
  }

  async noteLiveBuild(build: string | null, core?: string | null): Promise<void> {
    if (!build || this.applied) return;
    this.bootBuild ??= build;
    if (build === this.latestBuild) return;
    this.latestBuild = build;
    if (build === this.bootBuild) {
      this.ready = false;
      this.notify();
    } else {
      await this.warmAndReady(core);
    }
  }

  private async warmAndReady(core?: string | null): Promise<void> {
    if (this.warming || this.applied) return;
    this.ready = false;
    this.warming = true;
    this.notify();
    let warmed = false;
    try {
      if (core) {
        const res = await fetch(core, { signal: AbortSignal.timeout(WARM_TIMEOUT_MS) });
        warmed = res.ok;
      }
    } catch {
      warmed = false;
    } finally {
      this.warming = false;
    }
    if (this.applied) return;
    if (this.latestBuild != null && this.latestBuild !== this.bootBuild) {
      this.ready = true;
      Logger.i(`Everglow update ready (${this.latestBuild}, pre-warmed: ${warmed})`);
    }
    this.notify();
  }

  applyNow = (): void => {
    if (this.applied) return;
    this.applied = true;
    if (this.pollTimer != null) {
      window.clearInterval(this.pollTimer);
      this.pollTimer = null;
    }
    this.notify();
    window.location.reload();
  };

  dismiss = (): void => {
    this.dismissedBuild = this.latestBuild;
    this.notify();
  };

  dispose(): void {
    if (this.pollTimer != null) {
      window.clearInterval(this.pollTimer);
      this.pollTimer = null;
    }
    this.cleanupListeners?.();
    this.cleanupListeners = null;
  }
}

export const appUpdateService = new AppUpdateService();

export function useAppUpdate(): AppUpdateService {
  useSyncExternalStore(appUpdateService.subscribe, appUpdateService.getVersion);
  return appUpdateService;
}
