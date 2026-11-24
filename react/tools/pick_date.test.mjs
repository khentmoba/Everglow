// Opening a second date picker must settle the first one, otherwise the caller
// awaiting it waits forever (and any "saving" state it guards stays stuck).
import test from 'node:test';
import assert from 'node:assert/strict';

function makeInput() {
  const listeners = new Map();
  return {
    type: '',
    min: '',
    max: '',
    value: '',
    style: {},
    removed: false,
    addEventListener(name, fn) {
      listeners.set(name, fn);
    },
    remove() {
      this.removed = true;
    },
    showPicker() {},
    fire(name) {
      listeners.get(name)?.();
    },
  };
}

const created = [];
globalThis.document = {
  createElement: () => {
    const input = makeInput();
    created.push(input);
    return input;
  },
  body: { appendChild() {} },
};

const { pickDate } = await import('../src/shared/utils/pickDate.ts');

const settle = (p, ms = 50) =>
  Promise.race([p, new Promise((r) => setTimeout(() => r('pending'), ms))]);

const day = (d) => new Date(d.getFullYear(), d.getMonth(), d.getDate());

test('a replaced picker resolves with null and is removed', async () => {
  const first = pickDate({ initial: new Date(2026, 0, 1), first: new Date(2026, 0, 1), last: new Date(2026, 11, 31) });
  const second = pickDate({ initial: new Date(2026, 1, 1), first: new Date(2026, 0, 1), last: new Date(2026, 11, 31) });

  assert.equal(await settle(first), null, 'the replaced picker must settle');
  assert.equal(created.at(-2).removed, true);

  const input = created.at(-1);
  input.value = '2026-03-04';
  input.fire('change');
  assert.deepEqual(await second, day(new Date(2026, 2, 4)));
});

test('a cancelled picker resolves with null and clears the active one', async () => {
  const picked = pickDate({ initial: new Date(2026, 0, 1), first: new Date(2026, 0, 1), last: new Date(2026, 11, 31) });
  created.at(-1).fire('cancel');
  assert.equal(await picked, null);
  // No stale picker is left to swallow the next open.
  const next = pickDate({ initial: new Date(2026, 0, 1), first: new Date(2026, 0, 1), last: new Date(2026, 11, 31) });
  assert.equal(await settle(next), 'pending');
  created.at(-1).fire('cancel');
  assert.equal(await next, null);
});
