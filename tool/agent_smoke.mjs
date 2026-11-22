import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { launch, serve, sleep, stop } from './perf/_harness.mjs';

const distDir = process.argv[2] || 'react/dist';
const filterArg = process.argv[3]?.trim() || '';

if (resolve(distDir) === resolve('react/dist')) {
  execFileSync(process.execPath, [fileURLToPath(new URL('../react/tools/check_dist.mjs', import.meta.url))], {
    stdio: 'inherit',
  });
}

const source = readFileSync(new URL('../react/src/core/agent/agentMode.ts', import.meta.url), 'utf8');
const aliasesBlock = source.split('routeAliases: {')[1].split('} as Record')[0];
const aliasEntries = [...aliasesBlock.matchAll(/('[^']+'|\w+)\s*:\s*'([^']+)'/g)].map((m) => [
  m[1].replace(/^'|'$/g, ''),
  m[2],
]);
const aliasMap = new Map(aliasEntries);
const allRoutes = ['/', ...new Set(aliasEntries.map(([, r]) => r))];
assert.ok(allRoutes.length > 1, 'No agent routes found in agentMode.ts');

let targetRoutes = allRoutes;
if (filterArg) {
  const mapped = aliasMap.get(filterArg.toLowerCase());
  const normalized = filterArg.startsWith('/') ? filterArg : `/${filterArg}`;
  if (mapped) targetRoutes = [mapped];
  else if (allRoutes.includes(normalized)) targetRoutes = [normalized];
  else throw new Error(`Unknown agent route/alias "${filterArg}". Known aliases: ${[...aliasMap.keys()].join(', ')}`);
}

const server = await serve(distDir, 0);
const chrome = await launch();
try {
  const base = `http://127.0.0.1:${server.address().port}`;
  const { cdp } = chrome;
  await cdp.send('Page.enable');
  await cdp.send('Runtime.enable');
  await cdp.send('Runtime.addBinding', { name: '__smokeErr' }).catch(() => {});
  await cdp.send('Page.addScriptToEvaluateOnNewDocument', {
    source: `(() => {
      window.addEventListener('error', (e) => window.__smokeErr?.(String(e.message || e.error || 'error')));
      window.addEventListener('unhandledrejection', (e) => window.__smokeErr?.(String(e.reason || 'unhandledrejection')));
    })();`,
  });
  for (const route of targetRoutes) {
    const errors = [];
    const offEx = cdp.on('Runtime.exceptionThrown', ({ exceptionDetails }) => {
      errors.push(exceptionDetails?.exception?.description || exceptionDetails?.text || 'Runtime exception');
    });
    const offBind = cdp.on('Runtime.bindingCalled', ({ name, payload }) => {
      if (name === '__smokeErr') errors.push(payload || 'Unhandled runtime error');
    });
    let state;
    try {
      await cdp.send('Page.navigate', { url: `${base}${route}${route.includes('?') ? '&' : '?'}agent=1` });

      const deadline = Date.now() + 12_000;
      while (Date.now() < deadline) {
        state = await cdp.eval(`(() => {
          const root = document.getElementById('root');
          const text = (document.body?.innerText || '').trim();
          return {
            children: root?.childElementCount ?? 0,
            textLen: text.length,
            path: location.pathname,
            hasError: text.includes('Something went wrong') || text.includes('Not ported yet'),
          };
        })()`);
        if (state.children > 0 && state.textLen > 0) break;
        await sleep(100);
      }
      assert.ok(state?.children > 0 && state?.textLen > 0, `${route}: React app did not mount`);
      assert.equal(state.hasError, false, `${route}: rendered fallback/error screen`);
      assert.equal(errors.length, 0, `${route}: unexpected runtime errors: ${errors.join('; ')}`);
    } finally {
      offEx();
      offBind();
    }
    console.log(`${route} -> ok (${state.path})`);
  }
} finally {
  server.closeAllConnections?.();
  server.close();
  await stop(chrome);
}
