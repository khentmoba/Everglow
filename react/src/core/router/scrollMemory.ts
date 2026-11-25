import { useEffect, useLayoutEffect, useRef, type RefObject } from 'react';
import { Prefs } from '../system/prefs';

const PREFIX = 'scroll:';
const memoryOffsets = new Map<string, number>();

function readOffset(key: string, persist = true): number {
  const cached = memoryOffsets.get(key);
  if (cached != null) return cached;
  if (!persist) return 0;
  const raw = Prefs.getString(`${PREFIX}${key}`);
  if (!raw) return 0;
  const parsed = Number.parseFloat(raw);
  if (!Number.isFinite(parsed) || parsed <= 0) return 0;
  memoryOffsets.set(key, parsed);
  return parsed;
}

function writeOffset(key: string, offset: number, persist = true): void {
  const clamped = Math.max(0, Math.round(offset));
  if (clamped <= 0) {
    memoryOffsets.delete(key);
    Prefs.remove(`${PREFIX}${key}`);
    return;
  }
  memoryOffsets.set(key, clamped);
  if (persist) Prefs.set(`${PREFIX}${key}`, String(clamped));
  else Prefs.remove(`${PREFIX}${key}`);
}

export const ScrollMemory = {
  get: readOffset,
  save: writeOffset,
  clear(key: string): void {
    memoryOffsets.delete(key);
    Prefs.remove(`${PREFIX}${key}`);
  },
};

/**
 * Saves and restores `scrollTop` for an overflow-y scroll container across
 * route navigation. Keeps retrying as async sections expand the container
 * until the target offset is reached or the user interacts.
 */
export function useRememberedScroll(
  key: string,
  ref: RefObject<HTMLDivElement | null>,
  ready = true,
  options?: { persist?: boolean },
): void {
  const persist = options?.persist ?? true;
  const restoringRef = useRef(false);
  const lastKnownScrollRef = useRef(0);

  useLayoutEffect(() => {
    return () => {
      const el = ref.current;
      if (!ready || restoringRef.current) return;
      const offset = el && el.isConnected && el.scrollHeight > el.clientHeight
        ? el.scrollTop
        : lastKnownScrollRef.current;
      writeOffset(key, offset, persist);
    };
  }, [key, ref, ready, persist]);

  useEffect(() => {
    const el = ref.current;
    if (!el || !ready) return;
    if (!persist) Prefs.remove(`${PREFIX}${key}`);

    const target = readOffset(key, persist);
    let restoring = target > 0;
    restoringRef.current = restoring;
    let userTouched = false;
    let lastApplied = 0;
    lastKnownScrollRef.current = el.scrollTop;

    const tryRestore = () => {
      if (!restoring || userTouched) return;
      const maxScroll = Math.max(0, el.scrollHeight - el.clientHeight);
      if (maxScroll <= 0) return;
      const next = Math.min(target, maxScroll);
      if (Math.abs(el.scrollTop - next) > 1) {
        el.scrollTop = next;
        lastApplied = el.scrollTop;
        lastKnownScrollRef.current = el.scrollTop;
      }
      if (el.scrollTop >= target - 2) {
        restoring = false;
        restoringRef.current = false;
      }
    };

    tryRestore();
    const raf = window.requestAnimationFrame(tryRestore);
    const stopRestoreTimer = window.setTimeout(() => {
      restoring = false;
      restoringRef.current = false;
    }, 2000);

    const observer =
      typeof ResizeObserver !== 'undefined' && el.firstElementChild
        ? new ResizeObserver(() => tryRestore())
        : null;
    if (observer && el.firstElementChild) {
      observer.observe(el.firstElementChild);
    }

    const cancelRestore = () => {
      userTouched = true;
      restoring = false;
      restoringRef.current = false;
    };

    let saveTimer: number | undefined;
    const onScroll = () => {
      if (restoring && lastApplied > 0 && Math.abs(el.scrollTop - lastApplied) > 16) {
        restoring = false;
        restoringRef.current = false;
        userTouched = true;
      }
      if (restoring) return;
      lastKnownScrollRef.current = el.scrollTop;
      const clamped = Math.max(0, Math.round(el.scrollTop));
      if (clamped <= 0) memoryOffsets.delete(key);
      else memoryOffsets.set(key, clamped);
      window.clearTimeout(saveTimer);
      if (persist) {
        saveTimer = window.setTimeout(() => writeOffset(key, el.scrollTop, true), 180);
      }
    };

    el.addEventListener('scroll', onScroll, { passive: true });
    el.addEventListener('wheel', cancelRestore, { passive: true });
    el.addEventListener('touchstart', cancelRestore, { passive: true });
    el.addEventListener('pointerdown', cancelRestore, { passive: true });

    return () => {
      window.cancelAnimationFrame(raf);
      window.clearTimeout(stopRestoreTimer);
      window.clearTimeout(saveTimer);
      observer?.disconnect();
      el.removeEventListener('scroll', onScroll);
      el.removeEventListener('wheel', cancelRestore);
      el.removeEventListener('touchstart', cancelRestore);
      el.removeEventListener('pointerdown', cancelRestore);
    };
  }, [key, ref, ready, persist]);
}
