// Runs the real release app in disposable Chrome, without login or couple data.
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {launch, serve, sleep, stop} from './perf/_harness.mjs';

const source = readFileSync(new URL('../lib/core/agent/agent_mode.dart', import.meta.url), 'utf8');
const aliases = [...source.split('routeAliases = {')[1].split('};')[0].matchAll(/'([^']+)': '([^']+)'/g)]
  .map(match => [match[1], match[2]]);
assert.ok(aliases.length > 0, 'No agent destinations found');
const markers = {
  '/cinema': /Everglow|Watch Together/i, '/anime': /My List/i,
  '/manga': /Mangacelestia|Latest Updates|Hot Manga/i, '/books': /Books|Categories/i,
  '/dashboard': /Forever In Bloom/i,
  '/sanctuary': /Sanctuary/, '/gallery': /Memory Gallery/, '/journal': /Our Journal/,
  '/tonight': /Tonight/, '/calendar': /Shared Calendar/, '/garden': /Our Garden/,
  '/starlight': /Starlight|star/i, '/play-zone': /Play Zone/, '/academy': /Academy Hub/,
  '/trips': /Trip Kit/, '/canvas': /Everglow Canvas/, '/bucket-list': /Our Bucket List/,
  '/money': /Our Money/, '/jukebox': /What we're listening to/,
};
const server = await serve(process.argv[2] || 'build/web', 0);
let browser;
try {
  browser = await launch(0, {dpr:1});
  const {cdp} = browser;
  await cdp.send('Page.enable');
  await cdp.send('Page.addScriptToEvaluateOnNewDocument', {source:
    `localStorage.setItem('flutter.route_memory:last_location', JSON.stringify('/journal'));`});
  const origin = `http://127.0.0.1:${server.address().port}`;
  const filter = process.argv[3];
  for (const width of [430, 810]) {
    await cdp.send('Emulation.setDeviceMetricsOverride', {width,height:932,deviceScaleFactor:1,mobile:false});
    for (const [alias, destination] of aliases.filter(([alias]) => !filter || alias === filter)) {
      const expected = new URL(destination, origin);
      assert.ok(markers[expected.pathname], `Missing screen assertion for ${alias}`);
      await cdp.send('Page.navigate', {url:`${origin}/?agent=${alias}`});
      const deadline = Date.now() + 30000;
      let page;
      while (Date.now() < deadline) {
        page = await cdp.eval(`(() => {
          document.querySelector('flt-semantics-placeholder')?.click();
          Array.from(document.querySelectorAll('flt-semantics[role="button"]'))
            .find(el => el.innerText.includes('Collapse HUD'))?.click();
          const text = document.body?.innerText ?? '';
          return {path:location.pathname,query:location.search,text,
            hud:text.includes('Collapse HUD'),
            canvas:!!(document.querySelector('canvas') || document.querySelector('flt-glass-pane')?.shadowRoot?.querySelector('canvas'))};
        })()`);
        if (!page.hud && page.path === expected.pathname && page.query === expected.search &&
            markers[expected.pathname].test(page.text)) break;
        await sleep(100);
      }
      assert.equal(page?.path, expected.pathname, `${alias} restored the wrong page`);
      assert.equal(page.query, expected.search, `${alias} lost its destination query`);
      assert.equal(page.hud, false, `${alias}: HUD cannot substitute for screen proof`);
      assert.match(page.text, markers[expected.pathname], `${alias}: destination screen did not render`);
      assert.ok(page.canvas, `${alias}: Flutter did not paint`);
      assert.doesNotMatch(page.text, /Page not found|Something went wrong|Could not open/i);
      console.log(`[agent-smoke] ${width}px ${alias} -> ${destination}: rendered`);
    }
  }
} finally {
  if (browser) await stop(browser);
  await new Promise(resolve => server.close(resolve));
}
