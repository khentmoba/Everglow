// Flutter's `MediaQuery.sizeOf(context)`.
import { useSyncExternalStore } from 'react';

let size = { width: window.innerWidth, height: window.innerHeight };
const listeners = new Set<() => void>();
window.addEventListener('resize', () => {
  size = { width: window.innerWidth, height: window.innerHeight };
  for (const l of listeners) l();
});

export function useViewport(): { width: number; height: number } {
  return useSyncExternalStore(
    (l) => {
      listeners.add(l);
      return () => listeners.delete(l);
    },
    () => size,
  );
}

const online = new Set<() => void>();
window.addEventListener('online', () => online.forEach((l) => l()));
window.addEventListener('offline', () => online.forEach((l) => l()));

/** `ConnectivityService.instance.isOnline`. */
export function useOnline(): boolean {
  return useSyncExternalStore(
    (l) => {
      online.add(l);
      return () => online.delete(l);
    },
    () => navigator.onLine,
  );
}
