import test from 'node:test';
import assert from 'node:assert/strict';
import {checkOwnership} from './remove_worktree.mjs';

const now = Date.now();
const target = 'C:/Users/Admin/.t3/worktrees/Everglow/task';
const owner = {threadId:'owner',worktreePath:target,settled:false,archived:false,status:'completed'};
const inventory = (threads = [owner]) => ({complete:true,capturedAt:new Date(now).toISOString(),threads});

test('merged/idle/completed threads still own their folder until settled', () => {
  for (const status of ['idle', 'completed', 'running', 'waiting']) {
    assert.throws(() => checkOwnership(inventory([{...owner,status}]), target, now), /belongs to thread/);
  }
  assert.throws(() => checkOwnership(inventory(), target.replaceAll('/', '\\'), now), /belongs to thread/);
  assert.doesNotThrow(() => checkOwnership(inventory([{...owner,settled:true}]), target, now));
  assert.throws(() => checkOwnership(inventory([{...owner,settled:true,status:'running'}]), target, now), /belongs/);
});

test('missing, incomplete, stale and future inventories cannot authorize cleanup', () => {
  for (const value of [{}, {...inventory(),complete:false}, inventory([{}]),
    {...inventory(),capturedAt:new Date(now-31000).toISOString()},
    {...inventory(),capturedAt:new Date(now+1000).toISOString()}]) {
    assert.throws(() => checkOwnership(value, target, now));
  }
});
