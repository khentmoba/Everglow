// Flutter's `MediaQuery.sizeOf(context)`.
import { useSyncExternalStore } from 'react';

let size = { width: window.innerWidth, height: window.innerHeight };
const listeners = new Set<() => void>();
let resizeRaf = 0;

function isIosStandalone(): boolean {
  const standalone =
    window.matchMedia?.('(display-mode: standalone)').matches ||
    (navigator as Navigator & { standalone?: boolean }).standalone === true;
  if (!standalone) return false;
  return typeof CSS !== 'undefined' && typeof CSS.supports === 'function' && CSS.supports('-webkit-touch-callout', 'none');
}

function syncIosStandaloneHeight(): void {
  if (!isIosStandalone()) return;
  const vv = window.visualViewport;
  if (vv && window.innerHeight - vv.height >= 120) {
    document.documentElement.style.setProperty('--app-height', `${Math.round(vv.height)}px`);
  } else {
    document.documentElement.style.removeProperty('--app-height');
  }
}

function scheduleResize(): void {
  if (resizeRaf) return;
  resizeRaf = window.requestAnimationFrame(() => {
    resizeRaf = 0;
    syncIosStandaloneHeight();
    const width = window.innerWidth;
    const height = window.innerHeight;
    if (width === size.width && height === size.height) return;
    size = { width, height };
    for (const l of listeners) l();
  });
}

window.addEventListener('resize', scheduleResize);
window.addEventListener('orientationchange', scheduleResize);
window.visualViewport?.addEventListener('resize', scheduleResize);
syncIosStandaloneHeight();

function subscribeViewport(l: () => void): () => void {
  listeners.add(l);
  return () => listeners.delete(l);
}

function getViewportSnapshot(): { width: number; height: number } {
  return size;
}

export function useViewport(): { width: number; height: number } {
  return useSyncExternalStore(subscribeViewport, getViewportSnapshot);
}

const online = new Set<() => void>();
window.addEventListener('online', () => online.forEach((l) => l()));
window.addEventListener('offline', () => online.forEach((l) => l()));

function subscribeOnline(l: () => void): () => void {
  online.add(l);
  return () => online.delete(l);
}

function getOnlineSnapshot(): boolean {
  return navigator.onLine;
}

/** `ConnectivityService.instance.isOnline`. */
export function useOnline(): boolean {
  return useSyncExternalStore(subscribeOnline, getOnlineSnapshot);
}
