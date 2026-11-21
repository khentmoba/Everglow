import { Logger } from '../system/logger';
import { ValueNotifier } from '../system/store';

class ConnectivityServiceImpl {
  readonly isOnlineNotifier = new ValueNotifier<boolean>(
    typeof navigator === 'undefined' ? true : navigator.onLine !== false,
  );
  private initialized = false;
  private onOnline = () => {
    this.isOnlineNotifier.value = true;
  };
  private onOffline = () => {
    this.isOnlineNotifier.value = false;
  };

  get isOnline(): boolean {
    if (typeof navigator !== 'undefined' && navigator.onLine === false) return false;
    return this.isOnlineNotifier.value;
  }

  init(): void {
    if (this.initialized || typeof window === 'undefined') return;
    this.initialized = true;
    this.isOnlineNotifier.value = navigator.onLine !== false;
    window.addEventListener('online', this.onOnline);
    window.addEventListener('offline', this.onOffline);
  }

  async checkConnectivity(): Promise<boolean> {
    if (typeof navigator !== 'undefined' && navigator.onLine === false) {
      this.isOnlineNotifier.value = false;
      return false;
    }
    try {
      const resp = await fetch('/favicon.ico', {
        method: 'HEAD',
        cache: 'no-store',
        signal: AbortSignal.timeout(4000),
      });
      const ok = resp.ok;
      this.isOnlineNotifier.value = ok;
      return ok;
    } catch {
      this.isOnlineNotifier.value = false;
      return false;
    }
  }
}

export const ConnectivityService = new ConnectivityServiceImpl();

export async function withConnectivity<T>(
  operation: () => Promise<T>,
  opts: { fallback: T; context?: string },
): Promise<T> {
  if (!ConnectivityService.isOnline) {
    Logger.w(`${opts.context ?? 'Request'} skipped: device is offline`);
    return opts.fallback;
  }
  try {
    return await operation();
  } catch (e) {
    Logger.e(`${opts.context ?? 'Request'} failed`, e);
    return opts.fallback;
  }
}
