const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

function wrapper() {
  const handlers = {};
  const events = {};
  const parent = [];
  const native = [];
  const nodes = {};
  for (const id of ['upstream', 'loader', 'serverName', 'bar', 'error', 'retry']) {
    nodes[id] = {
      style: {}, contentWindow: {},
      classList: { add() {}, remove() {} },
      querySelectorAll: () => [],
      querySelector: () => ({ textContent: '' }),
      appendChild() {},
      addEventListener: (type, callback) => { events[id + ':' + type] = callback; }
    };
  }
  const window = {
    location: { search: '?tmdbId=42&type=tv&s=2&e=3&start=120' },
    parent: { postMessage: message => parent.push(message) },
    EverglowPlayer: { postMessage: message => native.push(JSON.parse(message)) },
    addEventListener: (type, callback) => { handlers[type] = callback; }
  };
  const sandbox = {
    window, URLSearchParams,
    MutationObserver: class { observe() {} },
    setTimeout: () => 1, clearTimeout() {},
    document: {
      documentElement: {},
      addEventListener() {},
      getElementById: id => nodes[id],
      createElement: () => ({ setAttribute() {}, addEventListener() {} })
    }
  };
  vm.runInNewContext(fs.readFileSync(path.join(__dirname, '../../web/embed.js'), 'utf8'), sandbox);
  return { nodes, events, handlers, parent, native, window };
}

test('owned wrapper reports exhausted sources to web and native', () => {
  const w = wrapper();
  assert.match(w.nodes.upstream.src, /s=2&e=3&start=120$/);
  w.events['upstream:error']();
  assert.equal(w.parent.at(-1).type, 'everglow-embed-failed');
  assert.equal(w.native.at(-1).type, 'everglow-embed-failed');
});

test('episode bridge requires the real upstream frame and exact origin', () => {
  const w = wrapper();
  const data = { type: 'cinesrc:nextepisode', season: 2, episode: 4 };
  w.handlers.message({ data, source: {}, origin: 'https://cinesrc.st' });
  w.handlers.message({ data, source: w.nodes.upstream.contentWindow, origin: 'https://foreign.test' });
  assert.equal(w.parent.length, 0);
  assert.equal(w.native.length, 0);
  w.handlers.message({ data, source: w.nodes.upstream.contentWindow, origin: 'https://cinesrc.st' });
  assert.equal(w.parent.at(-1).episode, 4);
  assert.equal(w.native.at(-1).episode, 4);
});

test('command relay forwards permitted commands to upstream player', () => {
  const w = wrapper();
  const upstreamMessages = [];
  w.nodes.upstream.contentWindow.postMessage = (msg, targetOrigin) => {
    upstreamMessages.push({ msg, targetOrigin });
  };

  // From non-parent source: ignored
  w.handlers.message({
    data: { type: 'cinesrc:command', command: 'pause' },
    source: {},
    origin: 'https://any.test',
  });
  assert.equal(upstreamMessages.length, 0);

  // Unrecognized command: ignored
  w.handlers.message({
    data: { type: 'cinesrc:command', command: 'destroy' },
    source: w.window.parent,
    origin: 'https://any.test',
  });
  assert.equal(upstreamMessages.length, 0);

  // Valid commands: forwarded with https://cinesrc.st origin
  w.handlers.message({
    data: { type: 'cinesrc:command', command: 'pause' },
    source: w.window.parent,
    origin: 'https://any.test',
  });
  assert.equal(upstreamMessages.length, 1);
  assert.equal(upstreamMessages[0].msg.command, 'pause');
  assert.equal(upstreamMessages[0].targetOrigin, 'https://cinesrc.st');

  w.handlers.message({
    data: { type: 'cinesrc:command', command: 'seek', args: [45.5] },
    source: w.window.parent,
    origin: 'https://any.test',
  });
  assert.equal(upstreamMessages.length, 2);
  assert.equal(upstreamMessages[1].msg.command, 'seek');
  assert.deepEqual(upstreamMessages[1].msg.args, [45.5]);
});

test('playback events from upstream player are forwarded to parent', () => {
  const w = wrapper();

  // From non-upstream origin: ignored
  w.handlers.message({
    data: { type: 'cinesrc:pause' },
    source: w.nodes.upstream.contentWindow,
    origin: 'https://evil.test',
  });
  assert.equal(w.parent.length, 0);

  // Valid playback events: forwarded to parent
  w.handlers.message({
    data: { type: 'cinesrc:play' },
    source: w.nodes.upstream.contentWindow,
    origin: 'https://cinesrc.st',
  });
  assert.equal(w.parent.at(-1).type, 'cinesrc:play');

  w.handlers.message({
    data: { type: 'cinesrc:timeupdate', currentTime: 120.5, duration: 300 },
    source: w.nodes.upstream.contentWindow,
    origin: 'https://cinesrc.st',
  });
  assert.equal(w.parent.at(-1).type, 'cinesrc:timeupdate');
  assert.equal(w.parent.at(-1).currentTime, 120.5);
  assert.equal(w.parent.at(-1).duration, 300);

  w.handlers.message({
    data: { type: 'cinesrc:response', command: 'getPaused', result: true },
    source: w.nodes.upstream.contentWindow,
    origin: 'https://cinesrc.st',
  });
  assert.equal(w.parent.at(-1).type, 'cinesrc:response');
  assert.equal(w.parent.at(-1).command, 'getPaused');
  assert.equal(w.parent.at(-1).result, true);
});
