import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';

const source = readFileSync(new URL('../web/flutter_bootstrap.js', import.meta.url), 'utf8')
  .replace('{{flutter_js}}', '').replace('{{flutter_build_config}}', '');
const html = readFileSync(new URL('../web/index.html', import.meta.url), 'utf8');

function boot(standalone, hasHost = true) {
  const listeners = {};
  const host = {style: {}};
  const document = {
    activeElement: null,
    getElementById: () => hasHost ? host : null,
    addEventListener: (name, fn) => { listeners[name] = fn; },
  };
  const viewport = {
    height: 932, offsetTop: 0, scale: 1,
    addEventListener: (name, fn) => { listeners[`viewport-${name}`] = fn; },
  };
  const window = {
    innerHeight: 932, visualViewport: viewport,
    __everglowIsStandalone: () => standalone,
    addEventListener: (name, fn) => { listeners[name] = fn; },
  };
  let config;
  vm.runInNewContext(source, {
    window, document, setTimeout: (fn) => fn(),
    _flutter: {loader: {load: (args) => { config = args.config; }}},
  });
  return {host, document, viewport, listeners, config};
}

test('installed app keeps its full-window host while editing', () => {
  const app = boot(true);
  assert.equal(app.config.hostElement, app.host);
  assert.equal(app.host.style.bottom, undefined);
  app.document.activeElement = {tagName: 'INPUT'};
  app.viewport.height = 600;
  assert.equal(app.listeners['viewport-resize'], undefined);
  assert.equal(app.host.style.bottom, undefined);
  app.document.activeElement = null;
  assert.equal(app.host.style.bottom, undefined);
});

test('browser tabs and cached shells without a host use full-page Flutter', () => {
  assert.equal(boot(false).config.hostElement, undefined);
  assert.equal(boot(true, false).config.hostElement, undefined);
});

test('iPhone launch metadata lets artwork paint behind the status bar', () => {
  assert.match(html, /name="apple-mobile-web-app-status-bar-style" content="black-translucent"/);
  assert.match(html, /name="viewport" content="[^"]*viewport-fit=contain"/);
});

for (const [mode, standalone] of [
  ['browser', false], ['ios', true], ['standalone', true], ['fullscreen', true],
]) {
  test(`viewport policy survives engine metadata changes (${mode})`, () => {
    const script = [...html.matchAll(/<script>([\s\S]*?)<\/script>/g)]
      .find((match) => match[1].includes('function lockMeta()'))[1];
    const events = {};
    const meta = (content) => ({
      content,
      getAttribute() { return this.content; },
      setAttribute(_, value) { this.content = value; },
    });
    let metas = [meta('width=device-width, initial-scale=1.0, maximum-scale=5.0')];
    const head = {appendChild: (node) => metas.push(node)};
    let mutation;
    let resizes = 0;
    vm.runInNewContext(script, {
      document: {
        head,
        querySelectorAll: () => metas,
        createElement: () => meta(''),
        addEventListener() {},
      },
      window: {
        navigator: {standalone: mode === 'ios'},
        matchMedia: (query) => ({matches: query === `(display-mode: ${mode})`}),
        addEventListener: (name, fn) => { events[name] = fn; },
        dispatchEvent: () => { resizes++; },
      },
      MutationObserver: class {
        constructor(fn) { mutation = fn; }
        observe() {}
      },
      Event: class {},
      setTimeout: (fn) => fn(),
    });
    const expected = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no, viewport-fit=' +
      (standalone ? 'cover' : 'contain');
    assert.equal(metas[0].content, expected);
    metas = [meta('width=device-width, viewport-fit=cover'), meta('initial-scale=1.0')];
    mutation();
    assert.ok(metas.every((node) => node.content === expected));
    const resizeCount = resizes;
    mutation();
    assert.equal(resizes, resizeCount, 'unchanged metadata must not cause a resize loop');
    metas = [];
    mutation();
    assert.equal(metas.length, 1);
    assert.equal(metas[0].content, expected);
    events['flutter-first-frame']();
    assert.equal(metas[0].content, expected);
  });
}
