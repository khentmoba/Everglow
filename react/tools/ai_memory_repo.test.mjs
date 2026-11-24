import assert from 'node:assert/strict';
import { register } from 'node:module';
import test from 'node:test';

const mockLoader = `
export async function resolve(specifier, context, nextResolve) {
  if (specifier === 'firebase/firestore') {
    return { url: 'mock:firestore', shortCircuit: true };
  }
  if (specifier.endsWith('/core/services/firebase')) {
    return { url: 'mock:firebase', shortCircuit: true };
  }
  if (specifier.endsWith('/core/system/logger')) {
    return { url: 'mock:logger', shortCircuit: true };
  }
  return nextResolve(specifier, context);
}

export async function load(url, context, nextLoad) {
  if (url === 'mock:firestore') {
    return {
      format: 'module',
      shortCircuit: true,
      source: \`
        export const state = {
          nextId: 1,
          failNextGetDocs: false,
          docs: [],
          deletedIds: [],
          pinnedUpdates: [],
        };
        export const collection = (...args) => ({ kind: 'col', args });
        export const doc = (...args) => ({ kind: 'doc', id: args.at(-1), args });
        export const query = (...args) => ({ kind: 'query', args });
        export const orderBy = () => ({});
        export const limit = () => ({});
        export const where = () => ({});
        export const serverTimestamp = () => 'SERVER_TS';
        export const Timestamp = { fromDate: (d) => ({ toDate: () => d }) };
        export async function getDocs() {
          if (state.failNextGetDocs) {
            state.failNextGetDocs = false;
            throw new Error('offline');
          }
          return { docs: state.docs };
        }
        export async function addDoc(_ref, data) {
          const id = 'fact_' + (state.nextId++);
          state.docs.unshift({ id, data: () => data });
          return { id };
        }
        export async function deleteDoc(ref) {
          state.deletedIds.push(ref.id);
        }
        export async function updateDoc(ref, data) {
          state.pinnedUpdates.push({ id: ref.id, data });
        }
      \`,
    };
  }
  if (url === 'mock:firebase') {
    return {
      format: 'module',
      shortCircuit: true,
      source: \`
        export const auth = { currentUser: { uid: 'clair-uid' } };
        export const db = {};
      \`,
    };
  }
  if (url === 'mock:logger') {
    return {
      format: 'module',
      shortCircuit: true,
      source: \`
        export const Logger = { d() {}, i() {}, w() {}, e() {} };
      \`,
    };
  }
  return nextLoad(url, context);
}
`;

register('./ai_chat_ts_loader.mjs', import.meta.url);
register(`data:text/javascript;base64,${Buffer.from(mockLoader).toString('base64')}`);

const { state: firestoreState } = await import('firebase/firestore');
const { AIMemoryRepository } = await import('../src/features/ai/aiMemoryRepo.ts');

test('AIMemoryRepository keeps Firestore doc ids on save/saveStructured so pin and delete work immediately', async () => {
  firestoreState.nextId = 1;
  firestoreState.docs = [];
  firestoreState.deletedIds = [];
  firestoreState.pinnedUpdates = [];

  const repo = new AIMemoryRepository();
  await repo.load();
  assert.equal(repo.isLoaded, true);

  await repo.save('Clair loves iced matcha');
  assert.equal(repo.facts.length, 1);
  assert.equal(repo.facts[0].id, 'fact_1');

  await repo.saveStructured({ fact: 'Anniversary is Feb 14', category: 'date' });
  assert.equal(repo.facts.length, 2);
  assert.equal(repo.facts[0].id, 'fact_2');

  await repo.setPinned('fact_2', true);
  assert.deepEqual(firestoreState.pinnedUpdates, [{ id: 'fact_2', data: { pinned: true } }]);
  assert.equal(repo.facts[0].pinned, true);

  await repo.delete('fact_2');
  assert.deepEqual(firestoreState.deletedIds, ['fact_2']);
  assert.equal(repo.facts.length, 1);
  assert.equal(repo.facts[0].id, 'fact_1');
});

test('AIMemoryRepository does not lock loaded=true after a failed Firestore read', async () => {
  firestoreState.failNextGetDocs = true;
  firestoreState.docs = [{ id: 'loaded_1', data: () => ({ fact: 'Khent makes pour-over coffee', category: 'habit' }) }];

  const repo = new AIMemoryRepository();
  await repo.load();
  assert.equal(repo.isLoaded, false);
  assert.equal(repo.facts.length, 0);

  await repo.load();
  assert.equal(repo.isLoaded, true);
  assert.equal(repo.facts.length, 1);
  assert.equal(repo.facts[0].id, 'loaded_1');
});
