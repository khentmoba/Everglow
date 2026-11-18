// Dart Streams, the small way: a Source is "call me with data until I
// unsubscribe". Ports lib/core/utils/firestore_stream_utils.dart's
// withFirestoreTimeout so live data waits, retries and gives up exactly like
// the Flutter app.
import { FirebaseError } from 'firebase/app';
import { useEffect, useState } from 'react';
import { Logger } from '../system/logger';

export type Listener<T> = { data: (value: T) => void; error?: (e: unknown) => void; done?: () => void };
export type Source<T> = (listener: Listener<T>) => () => void;

/** `Stream.value(x)`: one event, then done. */
export function just<T>(value: T): Source<T> {
  return (l) => {
    let live = true;
    queueMicrotask(() => {
      if (!live) return;
      l.data(value);
      l.done?.();
    });
    return () => {
      live = false;
    };
  };
}

/** A broadcast of changes: `emit()` re-sends `read()` to every listener. */
export class Changes<T> {
  private listeners = new Set<(v: T) => void>();
  constructor(private read: () => T) {}
  emit() {
    const v = this.read();
    for (const l of this.listeners) l(v);
  }
  /** First the current value, then every change (Dart `async*` + yield*). */
  source: Source<T> = (l) => {
    let live = true;
    const push = (v: T) => live && l.data(v);
    queueMicrotask(() => push(this.read()));
    this.listeners.add(push);
    return () => {
      live = false;
      this.listeners.delete(push);
    };
  };
}

function isPermanent(e: unknown): boolean {
  return (
    e instanceof FirebaseError &&
    ['failed-precondition', 'permission-denied', 'unauthenticated', 'invalid-argument', 'not-found'].includes(e.code)
  );
}

function shortError(e: unknown): string {
  if (e instanceof FirebaseError) {
    const msg = e.message.length > 120 ? `${e.message.slice(0, 120)}…` : e.message;
    return `${e.code}${msg ? ` (${msg})` : ''}`;
  }
  const s = String(e);
  return s.length > 160 ? `${s.slice(0, 160)}…` : s;
}

export class TimeoutError extends Error {}

/**
 * withFirestoreTimeout: on the web the first event gets 25s (and up to 3
 * attempts when `resubscribe` is given). Without `resubscribe`, a silent
 * stream just ends; with it, the last failure is reported as an error.
 */
export function withFirestoreTimeout<T>(
  first: Source<T>,
  opts: { label?: string; resubscribe?: () => Source<T>; maxAttempts?: number; retryDelay?: number } = {},
): Source<T> {
  const budget = 25_000;
  const maxAttempts = Math.max(3, opts.maxAttempts ?? 2);
  const retryDelay = opts.retryDelay ?? 2000;
  const name = opts.label ?? 'stream';
  return (l) => {
    let attempt = 0;
    let receivedFirst = false;
    let settled = false;
    let unsub: (() => void) | null = null;
    let budgetTimer = 0;
    let backoffTimer = 0;

    const cancelTimers = () => {
      clearTimeout(budgetTimer);
      clearTimeout(backoffTimer);
    };
    const cancelSub = () => {
      const u = unsub;
      unsub = null;
      u?.();
    };
    const finishError = (e: unknown) => {
      if (settled) return;
      settled = true;
      cancelTimers();
      cancelSub();
      Logger.e(`[Firestore] ${name} failed: ${shortError(e)}`);
      l.error?.(e);
    };
    const close = () => {
      if (settled) return;
      settled = true;
      cancelTimers();
      l.done?.();
    };
    const reattach = () => {
      clearTimeout(backoffTimer);
      backoffTimer = window.setTimeout(() => {
        if (receivedFirst || settled || !opts.resubscribe) return;
        attach(opts.resubscribe());
      }, retryDelay);
    };
    const attach = (source: Source<T>) => {
      attempt++;
      clearTimeout(budgetTimer);
      budgetTimer = window.setTimeout(() => {
        if (receivedFirst || settled) return;
        cancelSub();
        if (opts.resubscribe && attempt < maxAttempts) {
          Logger.w(`[Firestore] ${name} no first event after ${budget / 1000}s (attempt ${attempt}/${maxAttempts}) — re-attaching…`);
          reattach();
        } else if (opts.resubscribe) {
          finishError(new TimeoutError(`No data from ${name} after ${maxAttempts} attempts`));
        } else {
          close();
        }
      }, budget);
      unsub = source({
        data: (v) => {
          if (!receivedFirst) {
            receivedFirst = true;
            clearTimeout(budgetTimer);
          }
          if (!settled) l.data(v);
        },
        error: (e) => {
          if (receivedFirst) {
            if (!settled) l.error?.(e);
            return;
          }
          cancelSub();
          if (isPermanent(e)) return finishError(e);
          if (opts.resubscribe && attempt < maxAttempts) {
            Logger.w(`[Firestore] ${name} attempt ${attempt}/${maxAttempts} failed before first event (${shortError(e)}) — re-attaching…`);
            reattach();
          } else {
            finishError(e);
          }
        },
        done: () => {
          if (receivedFirst) return close();
          cancelSub();
          if (opts.resubscribe && attempt < maxAttempts && !settled) reattach();
          else close();
        },
      });
    };
    attach(first);
    return () => {
      settled = true;
      cancelTimers();
      cancelSub();
    };
  };
}

/** `StreamBuilder`: latest value (or `initial`) from a source; resubscribes when `key` changes. */
export function useSource<T>(make: () => Source<T> | null, key: unknown[], initial: T): T {
  const [value, setValue] = useState<T>(initial);
  useEffect(() => {
    const source = make();
    if (!source) return;
    return source({ data: setValue });
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, key);
  return value;
}

/** `query.snapshots()` / `doc.snapshots()` as a Source. */
export function snapshots<S, T>(
  listen: (next: (s: S) => void, error: (e: unknown) => void) => () => void,
  map: (s: S) => T,
): Source<T> {
  return (l) => listen((s) => l.data(map(s)), (e) => l.error?.(e));
}

/** withGetTimeout: a one-off read gets at least 25s on the web, then fails. */
export function withGetTimeout<T>(read: Promise<T>, label = 'firestore read', ms = 10_000): Promise<T> {
  const effective = Math.max(ms, 25_000);
  return new Promise<T>((resolve, reject) => {
    const timer = window.setTimeout(() => {
      Logger.w(`[GetTimeout] ${label} timed out after ${effective / 1000}s`);
      reject(new TimeoutError(`Firestore read timed out after ${effective / 1000}s`));
    }, effective);
    read.then(
      (v) => (clearTimeout(timer), resolve(v)),
      (e) => (clearTimeout(timer), reject(e)),
    );
  });
}
