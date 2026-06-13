// Headless smoke test: runs the server in-process (no spawn), connects
// two WebSocket clients, and verifies a full match can be played.
// Run: npm test

'use strict';

const path = require('path');
const WebSocket = require('ws');

// Use a high random port to avoid conflicts with dev servers
const PORT = parseInt(process.env.TEST_PORT || String(30000 + Math.floor(Math.random() * 5000)), 10);
const BASE_URL = `ws://127.0.0.1:${PORT}`;

function makeClient(name, uid, color) {
  const ws = new WebSocket(BASE_URL);
  const events = [];
  let resolveOpen;
  let resolveWelcome;
  let resolveEnd;
  const open = new Promise((r) => (resolveOpen = r));
  const welcome = new Promise((r) => (resolveWelcome = r));
  const ended = new Promise((r) => (resolveEnd = r));

  ws.on('open', () => {
    ws.send(JSON.stringify({
      type: 'join', userId: uid, displayName: name, color, accentColor: '#fff',
    }));
    resolveOpen();
  });
  ws.on('message', (raw) => {
    const m = JSON.parse(raw.toString());
    events.push(m);
    if (m.type === 'welcome') resolveWelcome(m);
    if (m.type === 'matchEnd') resolveEnd(m);
  });
  ws.on('error', (e) => events.push({ type: '__error', message: e.message }));
  return { ws, events, open, welcome, ended, name };
}

function startServer(port) {
  return new Promise((resolve, reject) => {
    // Patch the PORT before requiring server.js so its listen() picks it up
    process.env.PORT = String(port);
    // Pass DEBUG_TICK through so the server logs hits/kills for debugging
    process.env.DEBUG_TICK = process.env.DEBUG_TICK || '';
    delete require.cache[require.resolve(path.join(__dirname, '..', 'server.js'))];
    const serverModule = require(path.join(__dirname, '..', 'server.js'));
    setImmediate(() => resolve(serverModule));
  });
}

function stopServer() {
  return new Promise((resolve) => {
    // Force shutdown: collect all handles and close them
    const handles = process._getActiveHandles ? process._getActiveHandles() : [];
    for (const h of handles) {
      try {
        if (h && typeof h.close === 'function' && h.constructor && h.constructor.name === 'Server') {
          h.close(() => resolve());
          return;
        }
      } catch (_) {}
    }
    resolve();
  });
}

async function main() {
  console.log(`starting server on port ${PORT}...`);
  await startServer(PORT);
  await new Promise((r) => setTimeout(r, 200)); // let it bind

  console.log('connecting Khent and Clair...');
  const khent = makeClient('Khent', 'khent_test', '#c2185b');
  const clair = makeClient('Clair', 'clair_test', '#d4b5d6');
  await Promise.all([khent.open, clair.open]);

  const [kWelcome, cWelcome] = await Promise.all([khent.welcome, clair.welcome]);
  if (kWelcome.matchId !== cWelcome.matchId) {
    throw new Error('match ids differ: ' + kWelcome.matchId + ' vs ' + cWelcome.matchId);
  }
  if (kWelcome.you.id !== 'khent_test' || cWelcome.you.id !== 'clair_test') {
    throw new Error('player ids do not match');
  }
  console.log(`  matched in ${kWelcome.matchId}, youAre=${kWelcome.youAre}`);

  // Run the match: Khent holds position firing right, Clair walks left.
  const matchStart = Date.now();
  let i = 0;
  while (Date.now() - matchStart < 30000) {
    i++;
    if (khent.ws.readyState === WebSocket.OPEN) {
      khent.ws.send(JSON.stringify({
        type: 'input',
        forward: false, backward: false, left: false, right: false,
        angle: 0,
      }));
      khent.ws.send(JSON.stringify({ type: 'shoot' }));
    }
    if (clair.ws.readyState === WebSocket.OPEN) {
      clair.ws.send(JSON.stringify({
        type: 'input',
        forward: false, backward: false, left: true, right: false,
        angle: 0,
      }));
      clair.ws.send(JSON.stringify({ type: 'shoot' }));
    }
    await new Promise((r) => setTimeout(r, 80));
    const ended = await Promise.race([
      khent.ended.then(() => 'k'),
      clair.ended.then(() => 'c'),
      new Promise((r) => setTimeout(() => r(null), 0)),
    ]);
    if (ended) break;
  }

  const endEvent = await Promise.race([
    khent.ended,
    clair.ended,
    new Promise((_, rj) => setTimeout(() => rj(new Error('match did not end in 30s')), 5000)),
  ]);

  console.log(`  match ended after ${i} input iterations`);
  console.log(`  reason=${endEvent.reason} winnerId=${endEvent.winnerId}`);
  console.log(`  khent ${endEvent.yourKills} - clair ${endEvent.opponentKills}`);

  if (endEvent.winnerId !== 'khent_test') {
    throw new Error(`expected khent_test to win, got ${endEvent.winnerId}`);
  }
  if (endEvent.yourKills < 1) {
    throw new Error(`expected khent kills>=1, got ${endEvent.yourKills}`);
  }
  if (endEvent.opponentKills !== 0) {
    throw new Error(`expected clair=0, got ${endEvent.opponentKills}`);
  }
  console.log('OK: khent won, scores match expectations');

  khent.ws.close();
  clair.ws.close();
}

main().then(
  async () => {
    console.log('PASS');
    await stopServer();
    process.exit(0);
  },
  async (e) => {
    console.error('FAIL:', e);
    await stopServer();
    process.exit(1);
  }
);
