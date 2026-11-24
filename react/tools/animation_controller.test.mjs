import assert from 'node:assert/strict';
import { register } from 'node:module';
import test from 'node:test';

const mockLoader = `
export async function resolve(specifier, context, nextResolve) {
  if (specifier === '../theme/motion') {
    return { url: 'mock:motion', shortCircuit: true };
  }
  return nextResolve(specifier, context);
}
export async function load(url, context, nextLoad) {
  if (url === 'mock:motion') {
    return { format: 'module', shortCircuit: true, source: 'export const linear = (t) => t;' };
  }
  return nextLoad(url, context);
}
`;

register(`data:text/javascript,${encodeURIComponent(mockLoader)}`);

const { AnimationController } = await import('../src/core/anim/controller.ts');

function installBrowserMocks() {
  const prevDoc = globalThis.document;
  const prevRaf = globalThis.requestAnimationFrame;
  const prevCancel = globalThis.cancelAnimationFrame;

  const listeners = new Map();
  let hidden = false;
  const doc = {
    get hidden() {
      return hidden;
    },
    setHidden(next) {
      hidden = next;
      for (const fn of listeners.get('visibilitychange') ?? []) fn();
    },
    addEventListener(type, fn) {
      if (!listeners.has(type)) listeners.set(type, new Set());
      listeners.get(type).add(fn);
    },
    removeEventListener(type, fn) {
      listeners.get(type)?.delete(fn);
    },
    listenerCount(type) {
      return listeners.get(type)?.size ?? 0;
    },
  };

  let nextId = 1;
  const queued = new Map();
  globalThis.document = doc;
  globalThis.requestAnimationFrame = (cb) => {
    const id = nextId++;
    queued.set(id, cb);
    return id;
  };
  globalThis.cancelAnimationFrame = (id) => {
    queued.delete(id);
  };

  return {
    doc,
    queued,
    step(now) {
      const entries = [...queued.entries()];
      queued.clear();
      for (const [, cb] of entries) cb(now);
    },
    restore() {
      if (prevDoc === undefined) delete globalThis.document;
      else globalThis.document = prevDoc;
      if (prevRaf === undefined) delete globalThis.requestAnimationFrame;
      else globalThis.requestAnimationFrame = prevRaf;
      if (prevCancel === undefined) delete globalThis.cancelAnimationFrame;
      else globalThis.cancelAnimationFrame = prevCancel;
    },
  };
}

test('AnimationController.repeat pauses RAF while document is hidden and resumes when visible', () => {
  const env = installBrowserMocks();
  try {
    const ctrl = new AnimationController(1000);
    ctrl.repeat({ reverse: true });
    assert.equal(env.queued.size, 1);
    assert.equal(ctrl.isAnimating, true);

    env.step(0);
    env.step(250);
    assert.equal(ctrl.value, 0.25);
    assert.equal(env.queued.size, 1);

    env.doc.setHidden(true);
    assert.equal(env.queued.size, 0, 'RAF should cancel when tab hides');
    assert.equal(ctrl.isAnimating, true, 'repeating controller stays logically animating while paused');

    env.doc.setHidden(false);
    assert.equal(env.queued.size, 1, 'RAF should resume when tab becomes visible');

    ctrl.dispose();
    assert.equal(env.queued.size, 0);
    assert.equal(env.doc.listenerCount('visibilitychange'), 0);
  } finally {
    env.restore();
  }
});

test('AnimationController.repeat started while hidden waits until tab becomes visible', () => {
  const env = installBrowserMocks();
  try {
    env.doc.setHidden(true);
    const ctrl = new AnimationController(1000);
    ctrl.repeat();
    assert.equal(env.queued.size, 0);
    assert.equal(ctrl.isAnimating, true);

    env.doc.setHidden(false);
    assert.equal(env.queued.size, 1);

    ctrl.stop();
    assert.equal(env.doc.listenerCount('visibilitychange'), 0);
  } finally {
    env.restore();
  }
});
