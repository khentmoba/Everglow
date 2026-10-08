import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';

const source = readFileSync(new URL('../web/flutter_bootstrap.js', import.meta.url), 'utf8')
  .replace('{{flutter_js}}', '').replace('{{flutter_build_config}}', '');

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
