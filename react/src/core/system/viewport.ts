// Flutter's `MediaQuery.sizeOf(context)`.
import { useSyncExternalStore } from 'react';

let size = { width: window.innerWidth, height: window.innerHeight };
const listeners = new Set<() => void>();
let resizeRaf = 0;
window.addEventListener('resize', () => {
  if (resizeRaf) return;
  resizeRaf = window.requestAnimationFrame(() => {
    resizeRaf = 0;
    const width = window.innerWidth;
    const height = window.innerHeight;
    if (width === size.width && height === size.height) return;
    size = { width, height };
    for (const l of listeners) l();
  });
});

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
