import test from 'node:test';
import assert from 'node:assert/strict';
import {judge, compare} from './smoke.mjs';

test('a healthy shelf passes even when some rows miss some titles', () => {
  assert.deepEqual(judge([
    {name: 'movie 603', played: true, rows: [{id: 'cine-1', played: true}, {id: 'cine-2', played: false}]},
    {name: 'movie 155', played: true, rows: [{id: 'cine-1', played: true}, {id: 'cine-2', played: true}]},
  ]), []);
});

test('the #595 shape fails: Vidrock rows listed for every title, playing none', () => {
  const rows = (fmov) => [{id: 'cine-1', played: fmov}, {id: 'cine-v1', played: false}, {id: 'cine-v2', played: false}];
  const failures = judge([
    {name: 'movie 603', played: true, rows: rows(true)},
    {name: 'tv 1399 s1e1', played: true, rows: rows(true)},
  ]);
  assert.deepEqual(failures, [
    'server cine-v1: played none of the titles it was listed for',
    'server cine-v2: played none of the titles it was listed for',
  ]);
});

test('a title where nothing plays fails', () => {
  assert.deepEqual(judge([{name: 'anime 21 ep1', played: false, rows: []}]), ['anime 21 ep1: no stream played']);
});

const run = (rows, played = true) => [{name: 'movie 603', played, rows}];

test('compare: an outage on both sides warns, it does not fail (fmov down, Yume from the US)', () => {
  const dead = run([{id: 'cine-1', played: false}], false);
  assert.deepEqual(compare(dead, dead), {
    failures: [],
    outages: ['movie 603: no stream played, before or after', 'server cine-1: played nothing, before or after'],
  });
});

test('compare: what played before and stopped after the change fails', () => {
  const {failures} = compare(run([{id: 'cine-1', played: true}]), run([{id: 'cine-1', played: false}], false));
  assert.deepEqual(failures, ['movie 603: played before, plays nothing now', 'server cine-1: played before, plays nothing now']);
});

test('compare: the #595 shape still fails, new rows that play nothing', () => {
  const before = run([{id: 'cine-1', played: true}]);
  const after = run([{id: 'cine-1', played: true}, {id: 'cine-v1', played: false}]);
  assert.deepEqual(compare(before, after).failures, ['server cine-v1: new, and played none of the titles it was listed for']);
});
