// Flutter's ValueNotifier + ValueListenableBuilder, as a tiny React store.
import { useSyncExternalStore } from 'react';

export class ValueNotifier<T> {
  private listeners = new Set<() => void>();
  constructor(private current: T) {}
  get value(): T {
    return this.current;
  }
  set value(next: T) {
    if (Object.is(next, this.current)) return;
    this.current = next;
    for (const l of this.listeners) l();
  }
  subscribe = (l: () => void) => {
    this.listeners.add(l);
    return () => this.listeners.delete(l);
  };
}

export function useValue<T>(notifier: ValueNotifier<T>): T {
  return useSyncExternalStore(notifier.subscribe, () => notifier.value);
}
