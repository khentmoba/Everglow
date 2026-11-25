import {spawn, execFileSync} from 'node:child_process';
import {readFileSync, writeFileSync} from 'node:fs';
import {pathToFileURL, fileURLToPath} from 'node:url';

export const CASES = [
  {name: 'movie 603', query: {source: 'cinema', type: 'movie', tmdbId: '603'}, minSeconds: 6000, maxSeconds: 10000},
  {name: 'movie 155', query: {source: 'cinema', type: 'movie', tmdbId: '155'}, minSeconds: 7000, maxSeconds: 11500},
  {name: 'tv 1399 s1e1', query: {source: 'cinema', type: 'tv', tmdbId: '1399', s: '1', e: '1'}, minSeconds: 2400, maxSeconds: 5400},
  {name: 'anime 16498 ep1', query: {source: 'everglow', anilistId: '16498', ep: '1'}, minSeconds: 900, maxSeconds: 2400},
  {name: 'anime 21 ep1', query: {source: 'everglow', anilistId: '21', ep: '1'}, minSeconds: 900, maxSeconds: 2400},
];

export const LIVE = 'https://everglow-stream.khentplaysmoba.workers.dev';
const TIMEOUT_MS = 30000;
const OVERALL_DEADLINE_MS = 180000;

/** Sum #EXTINF segment durations in a media playlist; returns null for master playlists. */
export function parseExtinfDuration(m3u8) {
  let total = 0;
  let count = 0;
  for (const m of String(m3u8 || '').matchAll(/^#EXTINF:\s*([0-9]+(?:\.[0-9]+)?)/gm)) {
    total += Number(m[1]);
    count++;
  }
  return count > 0 ? Math.round(total) : null;
}

/** Validate media playlist duration against expected bounds (ignores master playlists). */
export function checkPlaylistDuration(m3u8, {minSeconds, maxSeconds} = {}) {
  if (!minSeconds && !maxSeconds) return null;
  const seconds = parseExtinfDuration(m3u8);
  if (seconds == null) return null;
  if (minSeconds && seconds < minSeconds) return `decoy/short playlist (${seconds}s < ${minSeconds}s)`;
  if (maxSeconds && seconds > maxSeconds) return `unexpected long playlist (${seconds}s > ${maxSeconds}s)`;
  return null;
}

/** True when a failure reason indicates a transient upstream 502/503/504/timeout rather than a Worker 4xx/500 bug. */
export function isUpstreamOutageReason(why = '') {
  return /^(?:resolve|playlist) 50[234]\b|^timeout\b/i.test(String(why).trim());
}

const rowsPlayed = (results) => {
  const rows = new Map();
  for (const r of results) for (const row of r.rows) rows.set(row.id, rows.get(row.id) || row.played);
  return rows;
};

export function judge(results) {
  const failures = [];
  for (const r of results) if (!r.played) failures.push(`${r.name}: no stream played`);
  for (const [id, played] of rowsPlayed(results)) {
    if (!played) failures.push(`server ${id}: played none of the titles it was listed for`);
  }
  return failures;
}

export function compare(before, after) {
  const failures = [];
  const outages = [];
  const was = new Map(before.map((r) => [r.name, r.played]));
  for (const r of after) {
    if (r.played) continue;
    if (was.get(r.name)) failures.push(`${r.name}: played before, plays nothing now`);
    else outages.push(`${r.name}: no stream played, before or after`);
  }
  const rowsBefore = rowsPlayed(before);
  for (const [id, played] of rowsPlayed(after)) {
    if (played) continue;
    if (!rowsBefore.has(id)) failures.push(`server ${id}: new, and played none of the titles it was listed for`);
    else if (rowsBefore.get(id)) failures.push(`server ${id}: played before, plays nothing now`);
    else outages.push(`server ${id}: played nothing, before or after`);
  }
  return {failures, outages};
}

async function fetchWithTimeout(url, deadlineAt) {
  const remaining = deadlineAt ? Math.max(1000, Math.min(TIMEOUT_MS, deadlineAt - Date.now())) : TIMEOUT_MS;
  return fetch(url, {signal: AbortSignal.timeout(remaining), headers: {'User-Agent': 'everglow-smoke'}});
}

async function plays(origin, query, bounds = {}, deadlineAt = 0) {
  if (deadlineAt && Date.now() >= deadlineAt) return {ok: false, why: 'overall deadline exceeded'};
  try {
    const url = new URL('/proxyAnime', origin);
    for (const [k, v] of Object.entries({...query, format: 'json'})) url.searchParams.set(k, v);
    const res = await fetchWithTimeout(url, deadlineAt);
    if (res.status !== 200) return {ok: false, why: `resolve ${res.status}`};
    const body = await res.json();
    if (!body.src) return {ok: false, why: 'no src'};
    const src = new URL(body.src, origin);
    const list = await fetchWithTimeout(new URL(src.pathname + src.search, origin), deadlineAt);
    const text = list.status === 200 ? await list.text() : '';
    if (!text.trimStart().startsWith('#EXTM3U')) return {ok: false, why: `playlist ${list.status}`, body};
    const durationErr = checkPlaylistDuration(text, bounds);
    if (durationErr) return {ok: false, why: durationErr, body};
    return {ok: true, body};
  } catch (e) {
    return {ok: false, why: e.name === 'AbortError' || e.name === 'TimeoutError' ? 'timeout' : e.message};
  }
}

export async function collect(origin, log = console.log, {deadlineMs = OVERALL_DEADLINE_MS} = {}) {
  const deadlineAt = Date.now() + deadlineMs;
  const results = [];
  for (const c of CASES) {
    if (Date.now() >= deadlineAt) {
      log(`${c.name.padEnd(16)} FAIL (overall deadline exceeded)`);
      results.push({name: c.name, played: false, why: 'overall deadline exceeded', rows: []});
      continue;
    }
    const first = await plays(origin, c.query, c, deadlineAt);
    const servers = first.body?.servers || [];
    const tag = first.ok ? 'plays' : `${isUpstreamOutageReason(first.why) ? 'UPSTREAM' : 'FAIL'} (${first.why})`;
    log(`${c.name.padEnd(16)} ${tag}  rows=${servers.length}`);
    const rows = await Promise.all(servers.map(async (s) => {
      const r = await plays(origin, {...c.query, server: s.id}, c, deadlineAt);
      const rTag = r.ok ? 'plays' : `${isUpstreamOutageReason(r.why) ? 'upstream' : 'no'} (${r.why})`;
      log(`  ${String(s.id).padEnd(12)} ${String(s.label || '').padEnd(10)} ${rTag}`);
      return {id: s.id, played: r.ok, why: r.ok ? undefined : r.why};
    }));
    results.push({name: c.name, played: first.ok, why: first.ok ? undefined : first.why, rows});
  }
  return results;
}

function startRemote(port) {
  const cwd = fileURLToPath(new URL('..', import.meta.url));
  const child = spawn(`npx wrangler dev --remote --port ${Number(port)} --var CDN_STAMP_KEY:smoke-only-key`,
    {cwd, shell: true, stdio: ['ignore', 'pipe', 'pipe']});
  let stdout = '';
  let stderr = '';
  child.stdout.on('data', (d) => { stdout += d; });
  child.stderr.on('data', (d) => { stderr += d; });
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
    let lastHealthErr = '';
    for (let i = 0; i < 90; i++) {
      if (child.exitCode != null) {
        throw new Error(
          `wrangler dev exited (${child.exitCode}):\nstderr:\n${stderr.slice(-1500) || '(empty)'}\nstdout:\n${stdout.slice(-1000) || '(empty)'}`,
        );
      }
      try {
        const res = await fetch(`${origin}/health`, {signal: AbortSignal.timeout(3000)});
        if (res.ok) return origin;
        lastHealthErr = `HTTP ${res.status}`;
      } catch (e) {
        lastHealthErr = e?.message || String(e);
      }
      await new Promise((r) => setTimeout(r, 1000));
    }
    throw new Error(
      `wrangler dev --remote never became ready after 90s (last health check: ${lastHealthErr || 'no response'}):\n` +
      `stderr:\n${stderr.slice(-1500) || '(empty)'}\nstdout:\n${stdout.slice(-1000) || '(empty)'}`,
    );
  })();
  return {ready, stop};
}

function report({failures, outages}) {
  const warn = process.env.GITHUB_ACTIONS ? '::warning::' : 'warning: ';
  for (const o of outages) console.log(`${warn}upstream outage, not this change: ${o}`);
  if (failures.length) {
    console.error(`\n[smoke] FAIL\n${failures.join('\n')}`);
    process.exitCode = 1;
  } else {
    console.log(`\n[smoke] OK${outages.length ? ` (${outages.length} outage warnings above)` : ''}`);
  }
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const args = process.argv.slice(2);
  const flag = (name) => (args.includes(name) ? args[args.indexOf(name) + 1] : undefined);
  let remote = null;
  try {
    if (flag('--url')) {
      const results = await collect(flag('--url'));
      if (flag('--save')) {
        writeFileSync(flag('--save'), JSON.stringify(results));
        console.log(`\n[smoke] baseline saved to ${flag('--save')}`);
      } else if (flag('--compare')) {
        report(compare(JSON.parse(readFileSync(flag('--compare'), 'utf8')), results));
      } else {
        report({failures: judge(results), outages: []});
      }
    } else if (args.includes('--remote')) {
      console.log(`live Worker (baseline)\n`);
      const before = await collect(LIVE);
      remote = startRemote(8799);
      const origin = await remote.ready;
      console.log(`\nyour branch on the edge\n`);
      report(compare(before, await collect(origin)));
    } else {
      throw new Error('Usage: node scripts/smoke.mjs --remote | --url <origin> [--save <file> | --compare <file>]');
    }
  } catch (e) {
    console.error(`[smoke] ${e.message}`);
    process.exitCode = 1;
  } finally {
    remote?.stop();
  }
}
