import { ValueNotifier } from '../system/store';
import { ConnectivityService } from './connectivity';

export type NetworkQuality = 'fast' | 'moderate' | 'slow';

interface NetworkInformationLike {
  effectiveType?: string;
  rtt?: number;
  downlink?: number;
  saveData?: boolean;
  addEventListener?: (type: string, listener: () => void) => void;
}

function getConnection(): NetworkInformationLike | null {
  if (typeof navigator === 'undefined') return null;
  const nav = navigator as Navigator & {
    connection?: NetworkInformationLike;
    mozConnection?: NetworkInformationLike;
    webkitConnection?: NetworkInformationLike;
  };
  return nav.connection ?? nav.mozConnection ?? nav.webkitConnection ?? null;
}

class NetworkQualityServiceImpl {
  readonly qualityNotifier = new ValueNotifier<NetworkQuality>('fast');
  readonly saveDataNotifier = new ValueNotifier<boolean>(false);
  private initialized = false;

  init(): void {
    if (this.initialized || typeof window === 'undefined') return;
    this.initialized = true;
    this.refresh();
    const conn = getConnection();
    try {
      conn?.addEventListener?.('change', () => this.refresh());
    } catch {
      // Browser does not support navigator.connection change events.
    }
    window.addEventListener('online', () => this.refresh());
    window.addEventListener('offline', () => this.refresh());
  }

  refresh(): void {
    this.saveDataNotifier.value = this.computeSaveData();
    this.qualityNotifier.value = this.computeQuality();
  }

  get quality(): NetworkQuality {
    return this.qualityNotifier.value;
  }

  get isSlowConnection(): boolean {
    return this.qualityNotifier.value === 'slow' || this.saveDataNotifier.value;
  }

  get isSaveData(): boolean {
    return this.saveDataNotifier.value;
  }

  shouldSkipPrefetch(): boolean {
    return !ConnectivityService.isOnline || this.isSlowConnection;
  }

  preferredTmdbPosterSize(): 'w185' | 'w342' | 'w500' {
    if (this.isSlowConnection) return 'w185';
    if (this.qualityNotifier.value === 'moderate') return 'w342';
    return 'w500';
  }

  preferredTmdbCardSize(): 'w185' | 'w342' {
    return this.isSlowConnection ? 'w185' : 'w342';
  }

  preferredTmdbBackdropSize(large = false): 'w300' | 'w780' | 'w1280' {
    if (this.isSlowConnection) return 'w300';
    if (this.qualityNotifier.value === 'moderate') return 'w780';
    return large ? 'w1280' : 'w780';
  }

  timeoutMs(defaultMs: number): number {
    if (this.isSlowConnection) return Math.min(Math.round(defaultMs * 1.75), 35000);
    if (this.qualityNotifier.value === 'moderate') return Math.min(Math.round(defaultMs * 1.3), 25000);
    return defaultMs;
  }

  private computeSaveData(): boolean {
    try {
      const params = new URLSearchParams(window.location.search);
      const saveParam = params.get('savedata')?.toLowerCase();
      if (saveParam === '1' || saveParam === 'true') return true;
      if (saveParam === '0' || saveParam === 'false') return false;
    } catch {
      // Query params unavailable.
    }
    return getConnection()?.saveData === true;
  }

  private computeQuality(): NetworkQuality {
    try {
      const params = new URLSearchParams(window.location.search);
      const netParam = params.get('network')?.toLowerCase();
      if (netParam === 'slow' || netParam === '2g' || netParam === '3g' || netParam === 'slow-2g') {
        return 'slow';
      }
      if (netParam === 'moderate') return 'moderate';
      if (netParam === 'fast' || netParam === '4g') return 'fast';
    } catch {
      // Query params unavailable.
    }

    const conn = getConnection();
    if (!conn) return 'fast';
    if (conn.saveData) return 'slow';
    const eff = conn.effectiveType?.toLowerCase();
    if (eff === 'slow-2g' || eff === '2g' || eff === '3g') return 'slow';
    if (typeof conn.downlink === 'number' && conn.downlink > 0) {
      if (conn.downlink < 0.8) return 'slow';
      if (conn.downlink < 2.0) return 'moderate';
    }
    if (typeof conn.rtt === 'number' && conn.rtt > 0) {
      if (conn.rtt > 500) return 'slow';
      if (conn.rtt > 250) return 'moderate';
    }
    return 'fast';
  }
}

export const NetworkQualityService = new NetworkQualityServiceImpl();
