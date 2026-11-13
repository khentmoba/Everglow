// Plays real titles through a Worker running on Cloudflare's edge.
//
// Local tests mock every upstream, so they cannot see what an upstream sends
// to a datacenter. Vidrock passed them, then handed the edge one dead decoy URL
// for every title (#595, removed in #597). This asks the edge itself.
//
//   node scripts/smoke.mjs --remote          wrangler dev --remote (before merge)
//   node scripts/smoke.mjs --url <origin>    an already deployed Worker
import {spawn, execFileSync} from 'node:child_process';
import {pathToFileURL, fileURLToPath} from 'node:url';

export const CASES = [
  {name: 'movie 603', query: {source: 'cinema', type: 'movie', tmdbId: '603'}},
  {name: 'movie 155', query: {source: 'cinema', type: 'movie', tmdbId: '155'}},
  {name: 'tv 1399 s1e1', query: {source: 'cinema', type: 'tv', tmdbId: '1399', s: '1', e: '1'}},
  {name: 'anime 16498 ep1', query: {source: 'everglow', anilistId: '16498', ep: '1'}},
  {name: 'anime 21 ep1', query: {source: 'everglow', anilistId: '21', ep: '1'}},
];

const TIMEOUT_MS = 30000;

// results: [{name, played, rows: [{id, played}]}]
// A case fails when nothing plays. A picker row fails when it played none of
// the titles it was offered for: that is a button that can only fail.
export function judge(results) {
  const failures = [];
  for (const r of results) if (!r.played) failures.push(`${r.name}: no stream played`);
  const rows = new Map();
  for (const r of results) {
    for (const row of r.rows) rows.set(row.id, (rows.get(row.id) || false) || row.played);
  }
  for (const [id, played] of rows) {
    if (!played) failures.push(`server ${id}: played none of the titles it was listed for`);
  }
  return failures;
}

async function fetchWithTimeout(url) {
  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), TIMEOUT_MS);
  try {
    return await fetch(url, {signal: ctrl.signal, headers: {'User-Agent': 'everglow-smoke'}});
  } finally {
    clearTimeout(timer);
  }
}

// Plays = the resolver answered and the playlist it handed out is a real HLS
// playlist when fetched back through the Worker.
async function plays(origin, query) {
  try {
    const url = new URL('/proxyAnime', origin);
    for (const [k, v] of Object.entries({...query, format: 'json'})) url.searchParams.set(k, v);
    const res = await fetchWithTimeout(url);
    if (res.status !== 200) return {ok: false, why: `resolve ${res.status}`};
    const body = await res.json();
    if (!body.src) return {ok: false, why: 'no src'};
    // Back through the Worker under test: `wrangler dev --remote` stamps the
    // live hostname into src, and the live Worker cannot open our smoke key.
    const src = new URL(body.src, origin);
    const list = await fetchWithTimeout(new URL(src.pathname + src.search, origin));
    const text = list.status === 200 ? await list.text() : '';
    if (!text.trimStart().startsWith('#EXTM3U')) return {ok: false, why: `playlist ${list.status}`, body};
    return {ok: true, body};
  } catch (e) {
    return {ok: false, why: e.name === 'AbortError' ? 'timeout' : e.message};
  }
}

export async function smoke(origin, log = console.log) {
  const results = [];
  for (const c of CASES) {
    const first = await plays(origin, c.query);
    const servers = first.body?.servers || [];
    log(`${c.name.padEnd(16)} ${first.ok ? 'plays' : `FAIL (${first.why})`}  rows=${servers.length}`);
    const rows = await Promise.all(servers.map(async (s) => {
      const r = await plays(origin, {...c.query, server: s.id});
      log(`  ${String(s.id).padEnd(12)} ${String(s.label || '').padEnd(10)} ${r.ok ? 'plays' : `no (${r.why})`}`);
      return {id: s.id, played: r.ok};
    }));
    results.push({name: c.name, played: first.ok, rows});
  }
  return judge(results);
}

function startRemote(port) {
  const cwd = fileURLToPath(new URL('..', import.meta.url));
  // One fixed string: Windows needs a shell to find npx.
  const child = spawn(`npx wrangler dev --remote --port ${Number(port)} --var CDN_STAMP_KEY:smoke-only-key`,
    {cwd, shell: true, stdio: ['ignore', 'pipe', 'pipe']});
  let output = '';
  child.stdout.on('data', (d) => { output += d; });
  child.stderr.on('data', (d) => { output += d; });
  const stop = () => {
    if (child.exitCode != null) return;
    if (process.platform === 'win32') {
      try { execFileSync('taskkill', ['/pid', String(child.pid), '/T', '/F'], {stdio: 'ignore'}); } catch {}
    } else {
      child.kill('SIGTERM');
    }
  };
  const ready = (async () => {
    const origin = `http://127.0.0.1:${port}`;
    for (let i = 0; i < 90; i++) {
      if (child.exitCode != null) throw new Error(`wrangler dev exited:\n${output.slice(-2000)}`);
      try {
        if ((await fetch(`${origin}/health`)).ok) return origin;
      } catch {}
      await new Promise((r) => setTimeout(r, 1000));
    }
    throw new Error(`wrangler dev --remote never became ready:\n${output.slice(-2000)}`);
  })();
  return {ready, stop};
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const args = process.argv.slice(2);
  const urlAt = args.indexOf('--url');
  let remote = null;
  try {
    let origin;
    if (urlAt >= 0 && args[urlAt + 1]) {
      origin = args[urlAt + 1];
    } else if (args.includes('--remote')) {
      remote = startRemote(8799);
      origin = await remote.ready;
    } else {
      throw new Error('Usage: node scripts/smoke.mjs --remote | --url <origin>');
    }
    const failures = await smoke(origin);
    if (failures.length) {
      console.error(`\n[smoke] FAIL\n${failures.join('\n')}`);
      process.exitCode = 1;
    } else {
      console.log('\n[smoke] OK — every case played, every listed server played at least once');
    }
  } catch (e) {
    console.error(`[smoke] ${e.message}`);
    process.exitCode = 1;
  } finally {
    remote?.stop();
  }
}
