// A small copy of Flutter's AnimationController so ported widgets keep the
// exact same timing: value runs 0..1 over `duration` ms on each frame.
import { useEffect, useReducer, useRef, useState } from 'react';
import { linear, type Curve } from '../theme/motion';

type Listener = () => void;

export class AnimationController {
  value = 0;
  duration: number;
  private target = 0;
  private from = 0;
  private start = 0;
  private span = 0;
  private frame = 0;
  private repeating: { reverse: boolean } | null = null;
  private done: (() => void) | null = null;
  private listeners = new Set<Listener>();

  constructor(duration: number) {
    this.duration = duration;
  }

  get isAnimating(): boolean {
    return this.frame !== 0;
  }

  addListener(l: Listener): () => void {
    this.listeners.add(l);
    return () => this.listeners.delete(l);
  }

  /** Runs toward 1. Resolves when it gets there (or is stopped). */
  forward(from?: number): Promise<void> {
    if (from != null) this.value = from;
    this.repeating = null;
    return this.animateTo(1);
  }

  reverse(): Promise<void> {
    this.repeating = null;
    return this.animateTo(0);
  }

  repeat(opts: { reverse?: boolean } = {}): void {
    this.repeating = { reverse: opts.reverse ?? false };
    void this.animateTo(this.value >= 1 && this.repeating.reverse ? 0 : 1);
  }

  stop(): void {
    this.repeating = null;
    if (this.frame) cancelAnimationFrame(this.frame);
    this.frame = 0;
    this.finish();
  }

  dispose(): void {
    this.stop();
    this.listeners.clear();
  }

  private animateTo(target: number): Promise<void> {
    if (this.frame) cancelAnimationFrame(this.frame);
    this.frame = 0;
    this.finish();
    this.target = target;
    this.from = this.value;
    this.span = Math.abs(target - this.value) * this.duration;
    if (this.span <= 0) {
      this.value = target;
      this.notify();
      return Promise.resolve();
    }
    return new Promise((resolve) => {
      this.done = resolve;
      this.start = -1;
      this.frame = requestAnimationFrame(this.tick);
    });
  }

  private tick = (now: number) => {
    if (this.start < 0) this.start = now;
    const t = Math.min(1, (now - this.start) / this.span);
    this.value = this.from + (this.target - this.from) * t;
    this.notify();
    if (t < 1) {
      this.frame = requestAnimationFrame(this.tick);
      return;
    }
    this.frame = 0;
    const repeat = this.repeating;
    if (repeat) {
      const next = repeat.reverse ? 1 - this.target : 1;
      if (!repeat.reverse) this.value = 0;
      this.finish();
      this.repeating = repeat;
      void this.animateTo(next);
      return;
    }
    this.finish();
  };

  private finish() {
    const done = this.done;
    this.done = null;
    done?.();
  }

  private notify() {
    for (const l of this.listeners) l();
  }
}

/** One controller for the life of a component; re-renders on every tick. */
export function useController(duration: number): AnimationController {
  const [controller] = useState(() => new AnimationController(duration));
  const [, rerender] = useReducer((n: number) => n + 1, 0);
  useEffect(() => {
    const off = controller.addListener(rerender);
    return () => {
      off();
      controller.stop();
    };
  }, [controller]);
  return controller;
}

/**
 * Flutter's `TweenAnimationBuilder` / implicit animation: returns a value
 * that animates from where it is to `target` whenever `target` changes.
 */
export function useAnimatedValue(target: number, duration: number, curve: Curve = linear): number {
  const controller = useController(duration);
  const range = useRef({ from: target, to: target });
  const first = useRef(true);
  useEffect(() => {
    if (first.current) {
      first.current = false;
      return;
    }
    const r = range.current;
    const current = r.from + (r.to - r.from) * curve(controller.value);
    range.current = { from: current, to: target };
    controller.duration = duration;
    void controller.forward(0);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [target]);
  const r = range.current;
  return r.from + (r.to - r.from) * curve(controller.value);
}
