'use strict';

// Guards for the HTML that media_proxy_html.js hands to the browser.
//
// proxyEmbed builds its ad-blocker as a string template, so every regex
// written with a single backslash in that template arrives in the browser
// with the backslash GONE (`\s` -> `s`, `\d` -> `d`). Those collapsed
// classes never match, so the overlay/pixel rules they sit in are dead
// code that still looks correct in the source. ESLint's
// `no-useless-escape` is what pointed this out in PR (functions-eslint),
// and these tests are why the doubled escapes must stay doubled.

const assert = require('node:assert/strict');
const test = require('node:test');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const src = fs.readFileSync(
  path.join(__dirname, '..', 'media_proxy_html.js'),
  'utf8',
);

/** The ad-blocker exactly as the browser receives it (template evaluated). */
function injectedAdBlockScript() {
  const raw = src.match(/const adBlockScript = (`[\s\S]*?\n`)/);
  assert.ok(raw, 'adBlockScript template not found — was it renamed?');
  // Intentional: evaluates the template from the source file above.
  return eval(raw[1]);
}

test('proxyEmbed is exported for the cinema embed route', () => {
  const { proxyEmbed } = require('../media_proxy_html.js');
  assert.equal(typeof proxyEmbed, 'function');
});

test('ad-block script stays valid JavaScript after escaping', () => {
  const script = injectedAdBlockScript();
  const body = script
    .replace(/^\s*<script>/, '')
    .replace(/<\/script>\s*$/, '');
  // Throws on a syntax error; parses cleanly means the escapes survived.
  new vm.Script(body, { filename: 'adblock.js' });
});

test('style regexes keep their character classes in the browser', () => {
  const script = injectedAdBlockScript();
  const zLine = script.split('\n').find((l) => l.includes('z-index:'));
  const dLine = script.split('\n').find((l) => l.includes('display:'));
  assert.ok(zLine && dLine, 'overlay style checks missing from the script');

  // The collapse this guards: `/z-index:s*[89]d{3,}/` (no backslashes).
  assert.match(zLine, /z-index:\\s\*\[89\]/, 'z-index check lost its \\s');
  assert.doesNotMatch(zLine, /z-index:s\*/, 'z-index check collapsed to bare s');
  assert.match(dLine, /display:\\s\*none/, 'display check lost its \\s');

  const zRe = eval(zLine.match(/\/z-index[^/]*\//)[0]);
  assert.equal(zRe.test('z-index:  99999'), true, 'high-z overlay not detected');
  assert.equal(zRe.test('z-index: 12'), false, 'normal z-index wrongly flagged');

  const dRe = eval(dLine.match(/\/display[^/]*\//)[0]);
  assert.equal(dRe.test('display:none;width:0'), true, 'hidden tracker not detected');
  assert.equal(dRe.test('display:block'), false, 'visible element wrongly flagged');
});
