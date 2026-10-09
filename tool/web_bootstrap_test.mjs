import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';

const source = readFileSync(new URL('../web/flutter_bootstrap.js', import.meta.url), 'utf8')
  .replace('{{flutter_js}}', '').replace('{{flutter_build_config}}', '');
const html = readFileSync(new URL('../web/index.html', import.meta.url), 'utf8');

test('screen-test installation saves a dedicated query-free launch page', () => {
  const manifest = JSON.parse(readFileSync(new URL('../web/manifest_screen.json', import.meta.url), 'utf8'));
  const launch = new URL(manifest.start_url, 'https://preview.example/');
  assert.equal(launch.pathname, '/screen_test.html');
  assert.equal(launch.search, '');
  assert.equal(new URL(manifest.id, launch).pathname, launch.pathname);
  assert.equal(manifest.display, 'standalone');
  const script = [...html.matchAll(/<script>([\s\S]*?)<\/script>/g)]
    .find(match => match[1].includes("href = 'manifest_screen.json'"))[1];
  for (const [search, expected] of [['', 'manifest.json'], ['?agent=dashboard', 'manifest.json'], ['?agent=dashboard&screencheck=1', 'manifest_screen.json']]) {
    const link = {href: 'manifest.json'};
    const title = {content: 'Everglow'};
    vm.runInNewContext(script, {
      URLSearchParams, window: {location: {search}},
      document: {querySelector: selector => selector.startsWith('link') ? link : title},
    });
    assert.equal(link.href, expected);
    assert.equal(title.content, expected === 'manifest.json' ? 'Everglow' : 'Everglow screen test');
  }
});

test('install page stays put in Safari and activates demo on a fresh installed launch', () => {
  const page = readFileSync(new URL('../web/screen_test.html', import.meta.url), 'utf8');
  const script = [...page.matchAll(/<script>([\s\S]*?)<\/script>/g)][0][1];
  const href = page.match(/<a href="([^"]+)"/)[1].replaceAll('&amp;', '&');
  const demo = new URL(href, 'https://preview.example/screen_test.html');
  assert.equal(demo.searchParams.get('agent'), 'dashboard');
  assert.equal(demo.searchParams.get('screencheck'), '1');
  assert.match(page, /rel="manifest" href="manifest_screen.json"/);
  for (const [ios, displayMode, expected] of [[false, false, null], [true, false, href], [false, true, href]]) {
    let destination = null;
    // No preferences or login state exist in this simulated new install.
    vm.runInNewContext(script, {
      navigator: {standalone: ios},
      window: {
        matchMedia: () => ({matches: displayMode}),
        location: {replace: value => { destination = value; }},
      },
    });
    assert.equal(destination, expected);
  }
});

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
  assert.match(html, /name="viewport" content="[^"]*viewport-fit=cover"/);
});

test('installed document and Flutter host share the full viewport height', () => {
  const rule = html.match(/html\.eg-standalone\s*,\s*html\.eg-standalone body\s*,\s*html\.eg-standalone #eg-app\s*\{([^}]+)\}/);
  assert.ok(rule, 'sizing only the document leaves the installed host on shortened fixed bounds');
  assert.match(rule[1], /height:\s*100vh\s*;/);
  assert.match(rule[1], /bottom:\s*auto\s*;/);
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
    const initialViewport = html.match(/<meta name="viewport" content="([^"]+)"/)[1];
    assert.match(initialViewport, /viewport-fit=cover$/, 'installed launch must not begin contained');
    let metas = [meta(initialViewport)];
    const head = {appendChild: (node) => metas.push(node)};
    let mutation;
    let resizes = 0;
    let installedClass;
    vm.runInNewContext(script, {
      document: {
        head,
        documentElement: {classList: {toggle: (name, value) => {
          assert.equal(name, 'eg-standalone');
          installedClass = value;
        }}},
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
    assert.equal(installedClass, standalone, 'host sizing must be selected before Flutter starts');
    assert.equal(metas[0].content, expected);
    metas = [meta('width=device-width, initial-scale=1.0, maximum-scale=5.0'), meta('initial-scale=1.0')];
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
