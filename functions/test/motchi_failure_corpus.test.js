'use strict';

/* Motchi failure corpus — every known way a tool call can fail, offline.
 *
 * Cases live in `motchi_failure_corpus.json` (data, easy to extend):
 *   validate-ok   representative args must PASS the guard (no false reject)
 *   validate-err  bad args must FAIL the guard (no false accept → executor crash)
 *   fastpath      whole-message fast-path fires / stays silent
 *   routing       adversarial phrasings route to the right tools
 *   followthrough bare yes to an offer keeps the write tools
 *
 * "Perfect agent" = this corpus at 100% plus the eval suites green.
 * Add a case whenever a new failure mode is found in the wild; fix the
 * agent code, never weaken the case.
 */

const { test } = require('node:test');
const assert = require('node:assert');
const tools = require('../motchi_tools.js');
const corpus = require('./motchi_failure_corpus.json');

function expand(value) {
  if (Array.isArray(value)) return value.map(expand);
  if (value && typeof value === 'object') {
    if (Array.isArray(value.$repeat)) {
      const [ch, n] = value.$repeat;
      return String(ch).repeat(n);
    }
    return Object.fromEntries(Object.entries(value).map(([k, v]) => [k, expand(v)]));
  }
  return value;
}

test('failure corpus: every case behaves', () => {
  const failures = [];
  for (const c of corpus) {
    try {
      switch (c.kind) {
        case 'validate-ok': {
          const r = tools.validateToolArgs(c.tool, expand(c.args));
          assert.equal(r.ok, true, `${c.tool} rejected good args: ${r.error}`);
          break;
        }
        case 'validate-err': {
          const r = tools.validateToolArgs(c.tool, expand(c.args));
          assert.equal(r.ok, false, `${c.tool} accepted bad args`);
          break;
        }
        case 'fastpath': {
          const got = tools.matchFastPath(c.message)?.tool ?? null;
          assert.equal(got, c.expect ?? null, `fastpath("${c.message}")`);
          break;
        }
        case 'schedulable': {
          const got = tools.isReminderSchedulable(c.text);
          assert.equal(got, c.expect, `schedulable("${c.text}")`);
          break;
        }
        case 'routing': {
          const names = tools.selectToolNames(c.message, '', c.context || '');
          for (const t of c.mustInclude || []) {
            assert.ok(names.includes(t), `routing("${c.message}") missing ${t} (got ${names.length})`);
          }
          for (const t of c.mustExclude || []) {
            assert.ok(!names.includes(t), `routing("${c.message}") wrongly attached ${t}`);
          }
          break;
        }
        case 'followthrough': {
          const names = tools.selectToolNames(c.message, c.offer);
          for (const t of c.mustInclude || []) {
            assert.ok(names.includes(t), `followthrough missing ${t}`);
          }
          break;
        }
        default:
          throw new Error(`unknown kind: ${c.kind}`);
      }
    } catch (e) {
      failures.push(`${c.id}: ${e.message.split('\n')[0]}`);
    }
  }
  const passed = corpus.length - failures.length;
  console.log(`failure corpus: ${passed}/${corpus.length} (${(passed / corpus.length * 100).toFixed(1)}%)`);
  for (const f of failures) console.log(`  FAIL ${f}`);
  assert.equal(failures.length, 0, `${failures.length} corpus failures`);
});

test('failure corpus covers every tool with a valid-args case', () => {
  const covered = new Set(
    corpus.filter((c) => c.kind === 'validate-ok').map((c) => c.tool)
  );
  for (const name of tools.TOOL_NAMES) {
    assert.ok(covered.has(name), `no validate-ok case for ${name}`);
  }
});
