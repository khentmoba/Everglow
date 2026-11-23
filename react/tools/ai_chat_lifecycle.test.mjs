import assert from 'node:assert/strict';
import { register } from 'node:module';
import test from 'node:test';

register('./ai_chat_ts_loader.mjs', import.meta.url);

const { aiChat } = await import('../src/features/ai/aiChat.ts');
const { auth } = await import('../src/core/services/firebase.ts');

function deferred() {
  let resolve;
  const promise = new Promise((done) => (resolve = done));
  return { promise, resolve };
}

test('stale session reads and switches are ignored after an auth reset', async () => {
  const repo = aiChat.repo;
  aiChat.resetForAuthChange();

  const read = deferred();
  const loading = repo.loadSession('old-session', () => read.promise);
  aiChat.resetForAuthChange();
  read.resolve({ exists: () => true, data: () => ({ messages: [], summary: 'PRIVATE OLD SUMMARY' }) });
  assert.equal(await loading, false);
  assert.equal(aiChat.assistantConversation, null);

  const loadSession = repo.loadSession;
  const save = repo.save;
  const switchRead = deferred();
  let saves = 0;
  repo.loadSession = () => switchRead.promise;
  repo.save = async () => { saves++; };
  try {
    const switching = aiChat.switchSession('old-session');
    aiChat.resetForAuthChange();
    repo.assistant = {
      id: 'assistant',
      feature: 'assistant',
      messages: [],
      createdAt: new Date(),
      updatedAt: new Date(),
    };
    switchRead.resolve(true);
    await switching;
    assert.equal(aiChat.currentSession, null);
    assert.equal(saves, 0);
  } finally {
    repo.loadSession = loadSession;
    repo.save = save;
    aiChat.resetForAuthChange();
  }
});

test('a retry does not resend study messages after auth changes during its delay', { timeout: 10_000 }, async () => {
  const oldFetch = globalThis.fetch;
  const oldDocument = globalThis.document;
  const oldSetTimeout = globalThis.setTimeout;
  let requests = 0;
  let current = true;
  let resumeRetry;
  const retryStarted = deferred();
  globalThis.document = { hidden: true, addEventListener() {}, removeEventListener() {} };
  globalThis.fetch = async () => {
    requests++;
    return new Response(JSON.stringify({ error: '503 temporary' }), {
      status: 503,
      headers: { 'Content-Type': 'application/json' },
    });
  };
  globalThis.setTimeout = (callback, delay, ...args) => {
    if (delay === 1000) {
      resumeRetry = callback;
      retryStarted.resolve();
      return 0;
    }
    return oldSetTimeout(callback, delay, ...args);
  };

  try {
    const reply = aiChat.callStream(
      [],
      'study',
      'test',
      { onChunk() {} },
      { enableThinking: false, canvasEnabled: false, artifactExpected: false },
      () => current,
    );
    await retryStarted.promise;
    current = false;
    resumeRetry();
    await assert.rejects(reply, /Reply stopped/);
    assert.equal(requests, 1);
  } finally {
    globalThis.fetch = oldFetch;
    globalThis.document = oldDocument;
    globalThis.setTimeout = oldSetTimeout;
    aiChat.resetForAuthChange();
  }
});

test('clear skips deleting when auth changes during archive', async () => {
  const repo = aiChat.repo;
  const previousUser = auth.currentUser;
  const previousArchive = repo.archiveSession;
  const archiveFinished = deferred();
  const archiveStarted = deferred();
  const deletedOwners = [];

  try {
    auth.currentUser = { uid: 'clear-owner-a' };
    aiChat.resetForAuthChange();
    repo.set('assistant', {
      id: 'assistant',
      feature: 'assistant',
      messages: [{}, {}],
      createdAt: new Date(),
      updatedAt: new Date(),
    });
    repo.archiveSession = async () => {
      archiveStarted.resolve();
      await archiveFinished.promise;
    };

    const clearing = repo.clear('assistant', true, async (ownerId) => { deletedOwners.push(ownerId); });
    await archiveStarted.promise;
    auth.currentUser = { uid: 'clear-owner-b' };
    aiChat.resetForAuthChange();
    archiveFinished.resolve();
    await clearing;
    assert.deepEqual(deletedOwners, []);
  } finally {
    repo.archiveSession = previousArchive;
    auth.currentUser = previousUser;
    aiChat.resetForAuthChange();
  }
});
