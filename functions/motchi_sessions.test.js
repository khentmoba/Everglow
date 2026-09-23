'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');

const { recordMotchiTurn, MAX_TURNS_PER_SESSION } = require('./motchi_sessions.js');
const common = require('./common.js');

test('motchi_sessions exports recordMotchiTurn and MAX_TURNS_PER_SESSION', () => {
  assert.equal(typeof recordMotchiTurn, 'function');
  assert.equal(typeof MAX_TURNS_PER_SESSION, 'number');
  assert.equal(MAX_TURNS_PER_SESSION, 50);
});

test('recordMotchiTurn creates new session doc on first turn', async () => {
  let docData = null;
  let docId = null;

  const fakeDocRef = {
    get: async () => ({ exists: false }),
    set: async (data) => {
      docData = data;
    },
    update: async () => {
      throw new Error('should not call update on new doc');
    },
  };

  const fakeDb = {
    collection: (name) => {
      assert.equal(name, 'motchi_sessions');
      return {
        doc: (id) => {
          docId = id;
          return fakeDocRef;
        },
      };
    },
  };

  const originalGetDb = common.getDb;
  const originalGetAdmin = common.getAdmin;
  common.getDb = () => fakeDb;
  common.getAdmin = () => ({
    firestore: {
      FieldValue: {
        serverTimestamp: () => 'SERVER_TIMESTAMP',
        increment: (n) => n,
        arrayUnion: (item) => [item],
      },
    },
  });

  try {
    const returnedId = await recordMotchiTurn({
      sessionId: 'test_sess_123',
      caller: 'khentsgdz',
      feature: 'assistant',
      userMessage: 'What is our schedule today?',
      assistantReply: 'You have a dinner planned at 7 PM!',
      tools: [{ name: 'get_calendar', args: {}, resultSummary: 'Dinner at 7 PM', elapsedMs: 120 }],
      reasoning: 'Checking calendar for events',
      model: 'qwen3.8-flash',
      durationMs: 1500,
    });

    assert.equal(returnedId, 'test_sess_123');
    assert.equal(docId, 'test_sess_123');
    assert.ok(docData, 'docData should be set');
    assert.equal(docData.id, 'test_sess_123');
    assert.equal(docData.caller, 'khentsgdz');
    assert.equal(docData.feature, 'assistant');
    assert.equal(docData.title, 'What is our schedule today?');
    assert.equal(docData.turnCount, 1);
    assert.equal(docData.turns.length, 1);
    assert.equal(docData.turns[0].userMessage, 'What is our schedule today?');
    assert.equal(docData.turns[0].assistantReply, 'You have a dinner planned at 7 PM!');
    assert.equal(docData.turns[0].tools.length, 1);
    assert.equal(docData.turns[0].tools[0].name, 'get_calendar');
    assert.equal(docData.turns[0].reasoning, 'Checking calendar for events');
    assert.equal(docData.turns[0].model, 'qwen3.8-flash');
    assert.equal(docData.turns[0].durationMs, 1500);
  } finally {
    common.getDb = originalGetDb;
    common.getAdmin = originalGetAdmin;
  }
});

test('recordMotchiTurn updates existing session on subsequent turns', async () => {
  let updateData = null;

  const existingTurn = {
    timestamp: '2026-09-23T10:00:00.000Z',
    userMessage: 'Hello Motchi',
    assistantReply: 'Hey Khent!',
    tools: [],
    reasoning: '',
    model: 'qwen3.8-flash',
    durationMs: 800,
    error: null,
    imageCount: 0,
  };

  const fakeDocRef = {
    get: async () => ({
      exists: true,
      data: () => ({
        id: 'test_sess_existing',
        caller: 'khentsgdz',
        turnCount: 1,
        turns: [existingTurn],
        toolsUsedTotal: 0,
      }),
    }),
    set: async () => {
      throw new Error('should not call set on existing doc');
    },
    update: async (data) => {
      updateData = data;
    },
  };

  const fakeDb = {
    collection: (name) => {
      assert.equal(name, 'motchi_sessions');
      return {
        doc: () => fakeDocRef,
      };
    },
  };

  const originalGetDb = common.getDb;
  const originalGetAdmin = common.getAdmin;
  common.getDb = () => fakeDb;
  common.getAdmin = () => ({
    firestore: {
      FieldValue: {
        serverTimestamp: () => 'SERVER_TIMESTAMP',
        increment: (n) => n,
        arrayUnion: (item) => [item],
      },
    },
  });

  try {
    const returnedId = await recordMotchiTurn({
      sessionId: 'test_sess_existing',
      caller: 'khentsgdz',
      feature: 'assistant',
      userMessage: 'Remind me to buy flowers',
      assistantReply: 'I added that reminder for you!',
      tools: [{ name: 'add_reminder', args: { title: 'buy flowers' }, resultSummary: 'success', elapsedMs: 95 }],
      durationMs: 1100,
    });

    assert.equal(returnedId, 'test_sess_existing');
    assert.ok(updateData, 'updateData should be set');
    assert.equal(updateData.turnCount, 2);
    assert.equal(updateData.turns.length, 2);
    assert.equal(updateData.turns[0].userMessage, 'Hello Motchi');
    assert.equal(updateData.turns[1].userMessage, 'Remind me to buy flowers');
    assert.equal(updateData.toolsUsedTotal, 1);
  } finally {
    common.getDb = originalGetDb;
    common.getAdmin = originalGetAdmin;
  }
});
