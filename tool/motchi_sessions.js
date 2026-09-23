#!/usr/bin/env node
'use strict';

/**
 * Everglow Motchi Sessions CLI Inspector
 *
 * Lets developers (Khent) and Pi agents inspect live Motchi sessions:
 * - List recent sessions: `node tool/motchi_sessions.js list`
 * - Inspect full session turns: `node tool/motchi_sessions.js show <sessionId>`
 * - Search session history: `node tool/motchi_sessions.js search <keyword>`
 * - Realtime tail: `node tool/motchi_sessions.js tail`
 *
 * Options:
 *   --limit <n>      Number of sessions to show (default: 15)
 *   --user <name>    Filter by caller (khentsgdz | clairjassen)
 *   --feature <name> Filter by feature (assistant | guardian | study)
 *   --json           Print raw JSON output
 */

const fs = require('fs');
const path = require('path');
const os = require('os');
const { execSync } = require('child_process');

const PROJECT_ID = 'everglow-1c6db';
const BASE_URL = `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents`;

// ── Colors & Formatting ──────────────────────────────────────────

const c = {
  reset: '\x1b[0m',
  bold: '\x1b[1m',
  dim: '\x1b[2m',
  cyan: '\x1b[36m',
  green: '\x1b[32m',
  yellow: '\x1b[33m',
  magenta: '\x1b[35m',
  red: '\x1b[31m',
  blue: '\x1b[34m',
  gray: '\x1b[90m',
};

function formatUser(caller) {
  if (caller === 'khentsgdz') return `${c.cyan}Khent 🦁${c.reset}`;
  if (caller === 'clairjassen') return `${c.magenta}Clair 🌸${c.reset}`;
  return `${c.gray}${caller || 'unknown'}${c.reset}`;
}

function timeAgo(isoString) {
  if (!isoString) return '';
  const d = new Date(isoString);
  const now = new Date();
  const diffSec = Math.floor((now - d) / 1000);
  if (diffSec < 60) return `${diffSec}s ago`;
  const diffMin = Math.floor(diffSec / 60);
  if (diffMin < 60) return `${diffMin}m ago`;
  const diffHours = Math.floor(diffMin / 60);
  if (diffHours < 24) return `${diffHours}h ago`;
  const diffDays = Math.floor(diffHours / 24);
  return `${diffDays}d ago`;
}

function formatDateTime(isoString) {
  if (!isoString) return 'unknown';
  const d = new Date(isoString);
  return d.toLocaleString('en-US', {
    month: 'short',
    day: 'numeric',
    hour: 'numeric',
    minute: '2-digit',
    hour12: true,
  });
}

// ── Authentication ───────────────────────────────────────────────

function getAccessToken() {
  const configPath = path.join(os.homedir(), '.config/configstore/firebase-tools.json');
  if (!fs.existsSync(configPath)) {
    throw new Error('Firebase credentials not found. Run "firebase login" first.');
  }

  let cfg = JSON.parse(fs.readFileSync(configPath, 'utf8'));
  const tokens = cfg.tokens || {};

  if (!tokens.access_token || (tokens.expires_at && tokens.expires_at < Date.now() + 60000)) {
    try {
      execSync('firebase projects:list', { stdio: 'ignore' });
      cfg = JSON.parse(fs.readFileSync(configPath, 'utf8'));
    } catch (_) {}
  }

  const token = cfg.tokens?.access_token;
  if (!token) {
    throw new Error('Failed to acquire valid access token from firebase-tools.json');
  }
  return token;
}

// ── Firestore REST Unwrapper ─────────────────────────────────────

function unwrapFirestore(val) {
  if (!val || typeof val !== 'object') return val;
  if ('stringValue' in val) return val.stringValue;
  if ('integerValue' in val) return parseInt(val.integerValue, 10);
  if ('doubleValue' in val) return parseFloat(val.doubleValue);
  if ('booleanValue' in val) return val.booleanValue;
  if ('timestampValue' in val) return val.timestampValue;
  if ('nullValue' in val) return null;
  if ('arrayValue' in val) return (val.arrayValue.values || []).map(unwrapFirestore);
  if ('mapValue' in val) {
    const res = {};
    for (const [k, v] of Object.entries(val.mapValue.fields || {})) {
      res[k] = unwrapFirestore(v);
    }
    return res;
  }
  if ('fields' in val) {
    const res = {};
    for (const [k, v] of Object.entries(val.fields || {})) {
      res[k] = unwrapFirestore(v);
    }
    return res;
  }
  return val;
}

// ── Firestore API Methods ────────────────────────────────────────

async function fetchSessions({ limit = 20, user = null, feature = null } = {}) {
  const token = getAccessToken();
  const url = `${BASE_URL}/motchi_sessions?pageSize=${Math.min(limit * 2, 100)}`;
  const resp = await fetch(url, {
    headers: { Authorization: `Bearer ${token}` },
  });

  if (!resp.ok) {
    const errText = await resp.text();
    throw new Error(`Firestore request failed (${resp.status}): ${errText}`);
  }

  const data = await resp.json();
  const docs = data.documents || [];

  let sessions = docs.map((d) => {
    const fields = unwrapFirestore(d);
    const id = d.name ? d.name.split('/').pop() : fields.id;
    return { id, ...fields };
  });

  if (user) {
    sessions = sessions.filter((s) => (s.caller || '').toLowerCase() === user.toLowerCase());
  }
  if (feature) {
    sessions = sessions.filter((s) => (s.feature || '').toLowerCase() === feature.toLowerCase());
  }

  // Sort by updatedAt descending
  sessions.sort((a, b) => {
    const timeA = new Date(a.updatedAtIso || a.updatedAt || 0).getTime();
    const timeB = new Date(b.updatedAtIso || b.updatedAt || 0).getTime();
    return timeB - timeA;
  });

  return sessions.slice(0, limit);
}

async function fetchSessionById(sessionId) {
  const token = getAccessToken();
  const url = `${BASE_URL}/motchi_sessions/${encodeURIComponent(sessionId)}`;
  const resp = await fetch(url, {
    headers: { Authorization: `Bearer ${token}` },
  });

  if (resp.status === 404) return null;
  if (!resp.ok) {
    const errText = await resp.text();
    throw new Error(`Firestore request failed (${resp.status}): ${errText}`);
  }

  const d = await resp.json();
  const fields = unwrapFirestore(d);
  return { id: sessionId, ...fields };
}

// ── Commands ─────────────────────────────────────────────────────

async function cmdList(args) {
  const limit = parseInt(args.limit || '15', 10);
  const user = args.user || null;
  const feature = args.feature || null;
  const asJson = args.json === true;

  const sessions = await fetchSessions({ limit, user, feature });

  if (asJson) {
    console.log(JSON.stringify(sessions, null, 2));
    return;
  }

  if (sessions.length === 0) {
    console.log(`\n${c.yellow}No Motchi sessions found in motchi_sessions collection.${c.reset}`);
    console.log(`${c.dim}Sessions are automatically saved as turns occur on the live site.${c.reset}\n`);
    return;
  }

  console.log(`\n${c.bold}🐾 Motchi Live Sessions (${sessions.length})${c.reset}\n`);

  for (const s of sessions) {
    const timeStr = formatDateTime(s.updatedAtIso || s.updatedAt);
    const ago = timeAgo(s.updatedAtIso || s.updatedAt);
    const turnCount = s.turnCount || (Array.isArray(s.turns) ? s.turns.length : 0);
    const callerFormatted = formatUser(s.caller);
    const title = s.title || 'New conversation';

    // Tool badges
    let toolBadges = '';
    const toolsUsedTotal = s.toolsUsedTotal || 0;
    if (toolsUsedTotal > 0) {
      toolBadges = ` ${c.yellow}[🛠 ${toolsUsedTotal} tool call${toolsUsedTotal > 1 ? 's' : ''}]${c.reset}`;
    }

    const errBadge = s.hasError ? ` ${c.red}[ERROR]${c.reset}` : '';

    console.log(`  ${c.bold}${title}${c.reset}${toolBadges}${errBadge}`);
    console.log(`  ${c.dim}ID:${c.reset} ${c.cyan}${s.id}${c.reset}  ${c.dim}|${c.reset}  ${callerFormatted}  ${c.dim}|${c.reset}  ${c.green}${turnCount} turn${turnCount === 1 ? '' : 's'}${c.reset}  ${c.dim}|${c.reset}  ${c.gray}${timeStr} (${ago})${c.reset}`);

    if (s.lastUserMessage) {
      console.log(`  ${c.gray}↳ Last user:${c.reset} "${s.lastUserMessage}"`);
    }
    if (s.lastAssistantReply) {
      const snippet = s.lastAssistantReply.split('\n')[0].slice(0, 100);
      console.log(`  ${c.gray}↳ Motchi:${c.reset} "${snippet}..."`);
    }
    console.log('');
  }

  console.log(`${c.dim}Tip: Run "node tool/motchi_sessions.js show <sessionId>" for turn-by-turn details.${c.reset}\n`);
}

async function cmdShow(sessionId, args) {
  if (!sessionId) {
    console.error(`${c.red}Error: Missing sessionId. Usage: node tool/motchi_sessions.js show <sessionId>${c.reset}`);
    process.exit(1);
  }

  const asJson = args.json === true;
  const session = await fetchSessionById(sessionId);

  if (!session) {
    console.error(`\n${c.red}Session not found: ${sessionId}${c.reset}\n`);
    process.exit(1);
  }

  if (asJson) {
    console.log(JSON.stringify(session, null, 2));
    return;
  }

  const title = session.title || 'Conversation';
  const caller = formatUser(session.caller);
  const started = formatDateTime(session.startedAtIso || session.startedAt);
  const updated = formatDateTime(session.updatedAtIso || session.updatedAt);
  const ago = timeAgo(session.updatedAtIso || session.updatedAt);
  const turns = Array.isArray(session.turns) ? session.turns : [];

  console.log(`\n${'='.repeat(70)}`);
  console.log(`${c.bold}🐾 Motchi Session:${c.reset} ${c.cyan}${title}${c.reset}`);
  console.log(`${'='.repeat(70)}`);
  console.log(`${c.dim}Session ID:${c.reset}  ${c.yellow}${session.id}${c.reset}`);
  console.log(`${c.dim}Caller:${c.reset}      ${caller}`);
  console.log(`${c.dim}Feature:${c.reset}     ${session.feature || 'assistant'}`);
  console.log(`${c.dim}Started:${c.reset}     ${started}`);
  console.log(`${c.dim}Updated:${c.reset}     ${updated} (${ago})`);
  console.log(`${c.dim}Turns:${c.reset}       ${turns.length}`);
  console.log(`${'='.repeat(70)}\n`);

  if (turns.length === 0) {
    console.log(`${c.dim}(No turn details recorded in this session doc)${c.reset}\n`);
    return;
  }

  turns.forEach((turn, idx) => {
    const turnNum = idx + 1;
    const timeStr = formatDateTime(turn.timestamp);
    const durationStr = turn.durationMs ? `${(turn.durationMs / 1000).toFixed(1)}s` : '';
    const modelStr = turn.model ? ` [${turn.model}]` : '';

    console.log(`${c.bold}${c.blue}── Turn ${turnNum} ───────────────────────────────────────${c.reset} ${c.dim}${timeStr}${c.reset}`);

    // User Message
    console.log(`\n${c.bold}👤 User:${c.reset}`);
    console.log(`  ${turn.userMessage || c.dim + '(empty message)' + c.reset}`);

    // Tools Executed
    if (Array.isArray(turn.tools) && turn.tools.length > 0) {
      console.log(`\n${c.bold}🛠 Tools Called (${turn.tools.length}):${c.reset}`);
      for (const t of turn.tools) {
        const ms = t.elapsedMs ? ` (${t.elapsedMs}ms)` : '';
        console.log(`  ${c.yellow}• ${t.name}${ms}${c.reset}`);
        if (t.args && Object.keys(t.args).length > 0) {
          console.log(`    ${c.dim}args:${c.reset} ${JSON.stringify(t.args)}`);
        }
        if (t.resultSummary) {
          const preview = t.resultSummary.replace(/\n/g, ' ').slice(0, 200);
          console.log(`    ${c.dim}result:${c.reset} ${preview}`);
        }
      }
    }

    // Reasoning / Thinking
    if (turn.reasoning) {
      console.log(`\n${c.bold}💭 Thinking:${c.reset}`);
      const lines = turn.reasoning.split('\n').slice(0, 6);
      lines.forEach((l) => console.log(`  ${c.gray}${l}${c.reset}`));
      if (turn.reasoning.split('\n').length > 6) {
        console.log(`  ${c.dim}...[more reasoning]${c.reset}`);
      }
    }

    // Motchi Assistant Reply
    console.log(`\n${c.bold}🐾 Motchi Reply:${c.reset}`);
    if (turn.assistantReply) {
      const indented = turn.assistantReply
        .split('\n')
        .map((line) => `  ${line}`)
        .join('\n');
      console.log(indented);
    } else {
      console.log(`  ${c.dim}(empty reply)${c.reset}`);
    }

    // Turn metadata
    const metaParts = [];
    if (durationStr) metaParts.push(`⏱ ${durationStr}`);
    if (modelStr) metaParts.push(modelStr.trim());
    if (turn.error) metaParts.push(`${c.red}⚠️ Error: ${turn.error}${c.reset}`);
    if (metaParts.length > 0) {
      console.log(`\n  ${c.dim}${metaParts.join(' | ')}${c.reset}`);
    }

    console.log('');
  });
}

async function cmdSearch(query, args) {
  if (!query) {
    console.error(`${c.red}Error: Missing query. Usage: node tool/motchi_sessions.js search <keyword>${c.reset}`);
    process.exit(1);
  }

  const q = query.toLowerCase();
  const sessions = await fetchSessions({ limit: 50 });
  const matched = [];

  for (const s of sessions) {
    const inTitle = (s.title || '').toLowerCase().includes(q);
    const inLastUser = (s.lastUserMessage || '').toLowerCase().includes(q);
    const inLastReply = (s.lastAssistantReply || '').toLowerCase().includes(q);
    let inTurns = false;

    if (Array.isArray(s.turns)) {
      for (const t of s.turns) {
        if ((t.userMessage || '').toLowerCase().includes(q) || (t.assistantReply || '').toLowerCase().includes(q)) {
          inTurns = true;
          break;
        }
      }
    }

    if (inTitle || inLastUser || inLastReply || inTurns) {
      matched.push(s);
    }
  }

  console.log(`\n${c.bold}🔍 Search Results for "${query}" (${matched.length})${c.reset}\n`);

  if (matched.length === 0) {
    console.log(`  ${c.dim}No sessions matched "${query}".${c.reset}\n`);
    return;
  }

  for (const s of matched) {
    console.log(`  • ${c.bold}${s.title || 'New conversation'}${c.reset} ${c.dim}(${s.id})${c.reset}`);
    console.log(`    ${formatUser(s.caller)} | ${formatDateTime(s.updatedAtIso || s.updatedAt)} | ${s.turnCount || 0} turns`);
    if (s.lastUserMessage) {
      console.log(`    ${c.gray}User:${c.reset} "${s.lastUserMessage}"`);
    }
    console.log('');
  }
}

async function cmdTail(args) {
  const intervalSec = parseInt(args.interval || '4', 10);
  console.log(`\n${c.bold}🐾 Motchi Session Live Tail (polling every ${intervalSec}s, press Ctrl+C to stop)${c.reset}\n`);

  let lastKnownMap = new Map();
  let firstPoll = true;

  async function poll() {
    try {
      const sessions = await fetchSessions({ limit: 10 });
      for (const s of sessions) {
        const prevTurns = lastKnownMap.get(s.id);
        const currentTurns = s.turnCount || (Array.isArray(s.turns) ? s.turns.length : 0);

        if (prevTurns === undefined) {
          lastKnownMap.set(s.id, currentTurns);
          if (!firstPoll) {
            console.log(`${c.green}✨ New session started:${c.reset} ${c.bold}${s.title}${c.reset} by ${formatUser(s.caller)} (${s.id})`);
          }
        } else if (currentTurns > prevTurns) {
          lastKnownMap.set(s.id, currentTurns);
          console.log(`${c.cyan}💬 New turn in session:${c.reset} ${c.bold}${s.title}${c.reset} (${s.id})`);
          console.log(`   ${formatUser(s.caller)}: "${s.lastUserMessage || ''}"`);
          if (s.lastAssistantReply) {
            const preview = s.lastAssistantReply.split('\n')[0].slice(0, 100);
            console.log(`   Motchi: "${preview}..."`);
          }
          console.log('');
        }
      }
      firstPoll = false;
    } catch (e) {
      console.warn(`${c.yellow}[tail warning] ${e.message}${c.reset}`);
    }
  }

  await poll();
  setInterval(poll, intervalSec * 1000);
}

// ── Argument Parser ──────────────────────────────────────────────

function parseArgs() {
  const raw = process.argv.slice(2);
  const positional = [];
  const flags = {};

  for (let i = 0; i < raw.length; i++) {
    const arg = raw[i];
    if (arg.startsWith('--')) {
      const key = arg.slice(2);
      if (i + 1 < raw.length && !raw[i + 1].startsWith('--')) {
        flags[key] = raw[++i];
      } else {
        flags[key] = true;
      }
    } else {
      positional.push(arg);
    }
  }

  return { positional, flags };
}

async function main() {
  const { positional, flags } = parseArgs();
  if (flags.help || flags.h || positional[0] === 'help') {
    printHelp();
    return;
  }
  const cmd = positional[0] || 'list';

  try {
    switch (cmd) {
      case 'list':
      case 'ls':
        await cmdList(flags);
        break;
      case 'show':
      case 'get':
      case 'inspect':
        await cmdShow(positional[1], flags);
        break;
      case 'search':
      case 'find':
        await cmdSearch(positional[1], flags);
        break;
      case 'tail':
      case 'watch':
        await cmdTail(flags);
        break;
      default:
        printHelp();
    }
  } catch (err) {
    console.error(`\n${c.red}Error:${c.reset} ${err.message}\n`);
    process.exit(1);
  }
}

function printHelp() {
  console.log(`
${c.bold}🐾 Everglow Motchi Sessions CLI${c.reset}

Usage:
  node tool/motchi_sessions.js [command] [options]

Commands:
  list                 List recent Motchi sessions (default)
  show <sessionId>     Show full turn-by-turn details of a session
  search <keyword>     Search sessions by query text
  tail                 Live tail of incoming turns and sessions

Options:
  --limit <n>          Number of sessions to return (default: 15)
  --user <name>        Filter by caller ('khentsgdz' or 'clairjassen')
  --feature <name>     Filter by feature ('assistant', 'guardian', etc.)
  --json               Output as JSON
`);
}

main();
