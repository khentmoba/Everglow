// Port of lib/shared/utils/scroll_memory.dart: a list remembers how far down
// it was, in the same `scroll:<key>` prefs the Flutter app writes.
import { useCallback, useEffect, useRef } from 'react';
import { Prefs } from '../../core/system/prefs';

const offsets = new Map<string, number>();
const SAVE_DELAY_MS = 500;

function initialOffset(key: string): number {
  if (offsets.has(key)) return offsets.get(key)!;
  const saved = Prefs.get(`scroll:${key}`);
  return typeof saved === 'number' && saved > 0 ? saved : 0;
}

function persist(key: string, offset: number) {
  offsets.set(key, offset);
  if (offset <= 0) Prefs.remove(`scroll:${key}`);
  else Prefs.set(`scroll:${key}`, offset);
}

/** RememberedScrollController: returns a ref for the scrolling element. */
export function useRememberedScroll<T extends HTMLElement>(key: string): (el: T | null) => void {
  const el = useRef<T | null>(null);
  const timer = useRef(0);

  useEffect(
    () => () => {
      if (timer.current) {
        clearTimeout(timer.current);
        if (el.current) persist(key, Math.max(0, el.current.scrollTop));
      }
    },
    [key],
  );

  const onScroll = useCallback(() => {
    clearTimeout(timer.current);
    timer.current = window.setTimeout(() => {
      timer.current = 0;
      if (el.current) persist(key, Math.max(0, el.current.scrollTop));
    }, SAVE_DELAY_MS);
  }, [key]);

  return useCallback(
    (node: T | null) => {
      el.current?.removeEventListener('scroll', onScroll);
      el.current = node;
      if (!node) return;
      const start = initialOffset(key);
      if (start > 0) requestAnimationFrame(() => (node.scrollTop = start));
      node.addEventListener('scroll', onScroll, { passive: true });
    },
    [key, onScroll],
  );
}
