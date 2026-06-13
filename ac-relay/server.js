// Everglow AC Relay — authoritative 1v1 game server.
//
// Protocol (JSON over WebSocket):
//   Client → Server:
//     { type: "join",   userId, displayName, color, preferredMatchId? }
//     { type: "input",  forward, backward, left, right, angle }
//     { type: "shoot" }
//     { type: "leave" }
//
//   Server → Client:
//     { type: "welcome", matchId, you, opponent, config }
//     { type: "state",   tick, you, opponent, bullets, elapsedMs }
//     { type: "hit",     shooterId, victimId, newHp }
//     { type: "kill",    killerId, victimId, killerKills, victimKills }
//     { type: "respawn", playerId, x, y }
//     { type: "matchEnd", winnerId|null, reason, yourKills, opponentKills }
//     { type: "opponentLeft" }
//     { type: "error",   message }
//
// Run: PORT=8787 node server.js
// Test client: open http://localhost:8787/test.html in two browser tabs.

'use strict';

const http = require('http');
const fs = require('fs');
const path = require('path');
const { WebSocketServer } = require('ws');

// ---------------------------------------------------------------------------
// Boot
// ---------------------------------------------------------------------------

console.error('[boot] process.env.DEBUG_TICK =', JSON.stringify(process.env.DEBUG_TICK));
console.error('[boot] process.env.DEBUG_SERVER =', JSON.stringify(process.env.DEBUG_SERVER));
console.error('[boot] process.env.PORT =', JSON.stringify(process.env.PORT));

// ---------------------------------------------------------------------------
// Config
// ---------------------------------------------------------------------------

const PORT = parseInt(process.env.PORT || '8787', 10);
const TICK_HZ = 20;
const TICK_MS = 1000 / TICK_HZ;
const MAX_KILLS = 5;
const MATCH_TIMEOUT_MS = 5 * 60 * 1000;

const ARENA = { width: 1000, height: 600 };
const PLAYER_RADIUS = 16;
const PLAYER_SPEED = 220;
const BULLET_SPEED = 720;
const BULLET_DAMAGE = 18;
// Range must span the arena (diagonal ~1170) so a stationary player
// can hit the other side.
const BULLET_RANGE = 1300;
const FIRE_COOLDOWN_MS = 220;
const RESPAWN_DELAY_MS = 1000;
const MAX_HP = 100;

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

/** @type {Map<WebSocket, ClientState>} */
const clients = new Map();
/** @type {Map<string, Match>} */
const matches = new Map();
/** @type {Map<string, WebSocket>} waiting pool, keyed by userId */
const waitingByUser = new Map();

let tickCounter = 0;

// ---------------------------------------------------------------------------
// Utilities
// ---------------------------------------------------------------------------

function uid(prefix = 'm') {
  return `${prefix}_${Math.random().toString(36).slice(2, 10)}${Date.now()
    .toString(36)
    .slice(-4)}`;
}

function safeSend(ws, obj) {
  if (!ws || ws.readyState !== ws.OPEN) return;
  try {
    ws.send(JSON.stringify(obj));
  } catch (_) {
    // ignore
  }
}

function dist(ax, ay, bx, by) {
  const dx = ax - bx;
  const dy = ay - by;
  return Math.sqrt(dx * dx + dy * dy);
}

// ---------------------------------------------------------------------------
// Player
// ---------------------------------------------------------------------------

class Player {
  constructor({ id, displayName, color, accentColor, spawnX, spawnY }) {
    this.id = id;
    this.displayName = displayName;
    this.color = color;
    this.accentColor = accentColor;
    this.spawnX = spawnX;
    this.spawnY = spawnY;
    this.x = spawnX;
    this.y = spawnY;
    this.angle = 0;
    this.hp = MAX_HP;
    this.maxHp = MAX_HP;
    this.kills = 0;
    this.alive = true;
    this.respawnAt = 0; // ms epoch
    this.lastFireAt = 0;
    this.input = {
      forward: false,
      backward: false,
      left: false,
      right: false,
      angle: 0,
    };
  }

  toNet() {
    return {
      id: this.id,
      displayName: this.displayName,
      color: this.color,
      accentColor: this.accentColor,
      x: this.x,
      y: this.y,
      angle: this.angle,
      hp: this.hp,
      maxHp: this.maxHp,
      kills: this.kills,
      alive: this.alive,
    };
  }

  applyInput(input) {
    Object.assign(this.input, input);
  }

  respawn(now) {
    this.x = this.spawnX;
    this.y = this.spawnY;
    this.hp = this.maxHp;
    this.alive = true;
    this.angle = 0;
    this.respawnAt = 0;
  }
}

// ---------------------------------------------------------------------------
// Bullet
// ---------------------------------------------------------------------------

class Bullet {
  constructor({ x, y, angle, shooterId, now }) {
    this.id = uid('b');
    this.x = x;
    this.y = y;
    this.angle = angle;
    this.vx = Math.cos(angle) * BULLET_SPEED;
    this.vy = Math.sin(angle) * BULLET_SPEED;
    this.shooterId = shooterId;
    this.spawnedAt = now;
    this.alive = true;
  }

  toNet() {
    return {
      id: this.id,
      x: this.x,
      y: this.y,
      shooterId: this.shooterId,
    };
  }
}

// ---------------------------------------------------------------------------
// Match
// ---------------------------------------------------------------------------

class Match {
  constructor(playerA, playerB) {
    this.id = uid('match');
    this.players = [playerA, playerB];
    this.bullets = [];
    this.createdAt = Date.now();
    this.endsAt = this.createdAt + MATCH_TIMEOUT_MS;
    this.ended = false;
    this.endReason = null;
    this.winnerId = null;
    this.lastTickAt = this.createdAt;
  }

  playerById(id) {
    return this.players.find((p) => p.id === id);
  }

  toClientView(forClient) {
    const you = this.players.find((p) => p.id === forClient.userId);
    const opponent = this.players.find((p) => p.id !== forClient.userId);
    return {
      matchId: this.id,
      you: you ? you.toNet() : null,
      opponent: opponent ? opponent.toNet() : null,
      config: {
        arena: ARENA,
        playerRadius: PLAYER_RADIUS,
        bulletSpeed: BULLET_SPEED,
        fireCooldownMs: FIRE_COOLDOWN_MS,
        maxKills: MAX_KILLS,
        matchTimeoutMs: MATCH_TIMEOUT_MS,
        maxHp: MAX_HP,
      },
    };
  }

  /**
   * Advance the simulation by `dtMs` milliseconds.
   * Returns a list of events to broadcast to both clients.
   */
  tick(dtMs) {
    if (this.ended) return [];
    const events = [];
    const now = Date.now();

    if (process.env.DEBUG_TICK) {
      const p0 = this.players[0];
      const p1 = this.players[1];
      console.error(
        `[tick] p0(${p0.x.toFixed(0)},${p0.y.toFixed(0)}) hp=${p0.hp} bullets=${this.bullets.length} | p1(${p1.x.toFixed(0)},${p1.y.toFixed(0)}) hp=${p1.hp}`
      );
    }

    // 1. Movement + aim
    for (const p of this.players) {
      if (!p.alive) {
        if (p.respawnAt && now >= p.respawnAt) {
          p.respawn(now);
          events.push({ kind: 'respawn', playerId: p.id, x: p.x, y: p.y });
        } else {
          continue;
        }
      }

      const { forward, backward, left, right, angle } = p.input;
      p.angle = angle;

      let dx = 0;
      let dy = 0;
      if (forward) dy -= 1;
      if (backward) dy += 1;
      if (left) dx -= 1;
      if (right) dx += 1;
      if (dx !== 0 || dy !== 0) {
        const mag = Math.sqrt(dx * dx + dy * dy);
        dx /= mag;
        dy /= mag;
        p.x = Math.max(
          PLAYER_RADIUS,
          Math.min(ARENA.width - PLAYER_RADIUS, p.x + dx * PLAYER_SPEED * (dtMs / 1000))
        );
        p.y = Math.max(
          PLAYER_RADIUS,
          Math.min(ARENA.height - PLAYER_RADIUS, p.y + dy * PLAYER_SPEED * (dtMs / 1000))
        );
      }
    }

    // 2. Bullets
    const survivors = [];
    for (const b of this.bullets) {
      b.x += b.vx * (dtMs / 1000);
      b.y += b.vy * (dtMs / 1000);

      // Out of arena
      if (b.x < 0 || b.x > ARENA.width || b.y < 0 || b.y > ARENA.height) {
        continue;
      }

      // Range exceeded
      if (now - b.spawnedAt > (BULLET_RANGE / BULLET_SPEED) * 1000) {
        continue;
      }

      // Player collision
      let hit = false;
      for (const p of this.players) {
        if (!p.alive || p.id === b.shooterId) continue;
        if (dist(b.x, b.y, p.x, p.y) <= PLAYER_RADIUS + 2) {
          p.hp = Math.max(0, p.hp - BULLET_DAMAGE);
          events.push({
            kind: 'hit',
            shooterId: b.shooterId,
            victimId: p.id,
            newHp: p.hp,
          });
          if (p.hp <= 0) {
            p.alive = false;
            p.respawnAt = now + RESPAWN_DELAY_MS;
            const killer = this.playerById(b.shooterId);
            if (killer) {
              killer.kills += 1;
              events.push({
                kind: 'kill',
                killerId: killer.id,
                victimId: p.id,
                killerKills: killer.kills,
                victimKills: p.kills,
              });
            }
            if (killer && killer.kills >= MAX_KILLS) {
              this.ended = true;
              this.endReason = 'kills';
              this.winnerId = killer.id;
              events.push({ kind: 'matchEnd' });
            }
          }
          hit = true;
          break;
        }
      }
      if (hit) continue;

      survivors.push(b);
    }
    this.bullets = survivors;

    // 3. Timeout
    if (!this.ended && now >= this.endsAt) {
      this.ended = true;
      this.endReason = 'timeout';
      const a = this.players[0];
      const b = this.players[1];
      if (a.kills > b.kills) this.winnerId = a.id;
      else if (b.kills > a.kills) this.winnerId = b.id;
      events.push({ kind: 'matchEnd' });
    }

    return events;
  }

  /** Try to fire a bullet for the given player. Returns the bullet or null. */
  tryFire(playerId, now) {
    if (this.ended) return null;
    const p = this.playerById(playerId);
    if (!p || !p.alive) return null;
    if (now - p.lastFireAt < FIRE_COOLDOWN_MS) return null;
    p.lastFireAt = now;
    const muzzle = PLAYER_RADIUS + 2;
    const b = new Bullet({
      x: p.x + Math.cos(p.angle) * muzzle,
      y: p.y + Math.sin(p.angle) * muzzle,
      angle: p.angle,
      shooterId: p.id,
      now,
    });
    this.bullets.push(b);
    return b;
  }

  contains(userId) {
    return this.players.some((p) => p.id === userId);
  }
}

// ---------------------------------------------------------------------------
// Client state
// ---------------------------------------------------------------------------

class ClientState {
  constructor(ws) {
    this.ws = ws;
    this.userId = null;
    this.displayName = 'You';
    this.color = '#c2185b';
    this.accentColor = '#e8d5b7';
    this.matchId = null;
    this.lastInputAt = 0;
  }
}

// ---------------------------------------------------------------------------
// Matchmaking
// ---------------------------------------------------------------------------

function makePlayerFromClient(client, role) {
  // role: 'host' (existing in lobby) or 'guest' (just joined)
  const spawnX = role === 'host' ? 150 : ARENA.width - 150;
  const spawnY = ARENA.height / 2;
  return new Player({
    id: client.userId,
    displayName: client.displayName,
    color: client.color,
    accentColor: client.accentColor,
    spawnX,
    spawnY,
  });
}

function tryMatchmake(client) {
  if (client.matchId) return;
  // Look for a waiting player other than this one
  for (const [otherId, otherWs] of waitingByUser) {
    if (otherId === client.userId) continue;
    const otherClient = clients.get(otherWs);
    if (!otherClient || otherClient.matchId) continue;

    // Pair them up. The one already in the lobby is the host
    // (spawns on the left); the new joiner is the guest (spawns right).
    const playerA = makePlayerFromClient(otherClient, 'host');
    const playerB = makePlayerFromClient(client, 'guest');
    const match = new Match(playerA, playerB);
    matches.set(match.id, match);
    if (process.env.DEBUG_TICK) {
      console.error(`[match] CREATED ${match.id} - now matches.size=${matches.size}`);
    }

    otherClient.matchId = match.id;
    client.matchId = match.id;

    waitingByUser.delete(otherId);
    waitingByUser.delete(client.userId);

    const viewA = match.toClientView({ userId: otherClient.userId });
    const viewB = match.toClientView({ userId: client.userId });

    safeSend(otherWs, { type: 'welcome', ...viewA, youAre: 'host' });
    safeSend(client.ws, { type: 'welcome', ...viewB, youAre: 'guest' });
    console.log(
      `[match] ${match.id} created: ${otherClient.displayName} vs ${client.displayName}`
    );
    return;
  }
  // No partner, sit in the lobby
  waitingByUser.set(client.userId, client.ws);
  safeSend(client.ws, {
    type: 'waiting',
    message: 'Waiting for your partner...',
  });
}

function teardownClient(client) {
  const ws = client.ws;
  if (client.matchId) {
    const match = matches.get(client.matchId);
    if (match && !match.ended) {
      match.ended = true;
      match.endReason = 'forfeit';
      const other = match.players.find((p) => p.id !== client.userId);
      match.winnerId = other ? other.id : null;
      const otherWs = other
        ? [...clients.entries()].find(([, c]) => c.userId === other.id)?.[0]
        : null;
      if (otherWs) {
        safeSend(otherWs, {
          type: 'matchEnd',
          reason: 'forfeit',
          winnerId: match.winnerId,
          yourKills: other.kills,
          opponentKills: match.players.find((p) => p.id === client.userId).kills,
        });
        safeSend(otherWs, { type: 'opponentLeft' });
      }
    }
    matches.delete(client.matchId);
  }
  if (client.userId) {
    waitingByUser.delete(client.userId);
  }
  clients.delete(ws);
}

// ---------------------------------------------------------------------------
// HTTP + WS server
// ---------------------------------------------------------------------------

const httpServer = http.createServer((req, res) => {
  if (req.url === '/health') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(
      JSON.stringify({
        status: 'ok',
        clients: clients.size,
        matches: matches.size,
        waiting: waitingByUser.size,
        uptime: process.uptime(),
      })
    );
    return;
  }
  if (req.url === '/' || req.url === '/test.html') {
    const file = path.join(__dirname, 'test.html');
    fs.readFile(file, (err, data) => {
      if (err) {
        res.writeHead(500);
        res.end('test.html missing');
        return;
      }
      res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
      res.end(data);
    });
    return;
  }
  res.writeHead(404);
  res.end('Not found');
});

const wss = new WebSocketServer({ server: httpServer });

wss.on('connection', (ws) => {
  if (process.env.DEBUG_TICK) console.error('[wss] NEW CONNECTION');
  const client = new ClientState(ws);
  clients.set(ws, client);
  console.log(`[ws] client connected (${clients.size} total)`);
  if (process.env.DEBUG_TICK) console.error(`[wss] clients.size now = ${clients.size}`);

  ws.on('message', (raw) => {
    if (process.env.DEBUG_TICK) {
      console.error(`[raw] ${raw.toString().slice(0, 200)}`);
    }
    let msg;
    try {
      msg = JSON.parse(raw.toString());
    } catch (e) {
      safeSend(ws, { type: 'error', message: 'Invalid JSON' });
      return;
    }
    if (process.env.DEBUG_TICK) {
      console.error(`[msg] before handleMessage type=${msg.type} clients.size=${clients.size}`);
    }
    handleMessage(client, msg);
    if (process.env.DEBUG_TICK) {
      console.error(`[msg] after handleMessage type=${msg.type} matches.size=${matches.size}`);
    }
  });

  ws.on('close', () => {
    console.log(`[ws] client disconnected (${clients.size} total)`);
    teardownClient(client);
  });

  ws.on('error', () => {
    teardownClient(client);
  });
});

function handleMessage(client, msg) {
  if (!msg || typeof msg !== 'object') return;
  if (process.env.DEBUG_TICK) {
    console.error(`[msg] type=${msg.type} userId=${client.userId || 'null'}`);
  }

  switch (msg.type) {
    case 'join': {
      if (typeof msg.userId !== 'string' || !msg.userId) {
        safeSend(client.ws, { type: 'error', message: 'userId required' });
        return;
      }
      client.userId = String(msg.userId).slice(0, 64);
      client.displayName = String(msg.displayName || 'You').slice(0, 32);
      client.color = String(msg.color || '#c2185b');
      client.accentColor = String(msg.accentColor || '#e8d5b7');
      tryMatchmake(client);
      return;
    }

    case 'input': {
      if (!client.matchId) return;
      const m = matches.get(client.matchId);
      if (!m) return;
      const player = m.playerById(client.userId);
      if (!player) return;
      player.applyInput({
        forward: !!msg.forward,
        backward: !!msg.backward,
        left: !!msg.left,
        right: !!msg.right,
        angle:
          typeof msg.angle === 'number'
            ? Math.max(-Math.PI, Math.min(Math.PI, msg.angle))
            : player.angle,
      });
      return;
    }

    case 'shoot': {
      if (!client.matchId) return;
      const m = matches.get(client.matchId);
      if (!m) return;
      m.tryFire(client.userId, Date.now());
      return;
    }

    case 'leave': {
      teardownClient(client);
      try {
        client.ws.close();
      } catch (_) {}
      return;
    }
  }
}

// ---------------------------------------------------------------------------
// Tick loop
// ---------------------------------------------------------------------------

function broadcastMatchState() {
  if (process.env.DEBUG_TICK) {
    console.error(`[broad] matches=${matches.size} clients=${clients.size}`);
  }
  if (matches.size === 0) return;
  for (const match of matches.values()) {
    if (match.ended) {
      // Send one final state + matchEnd, then clean up after a short delay
      for (const p of match.players) {
        const [otherWs] =
          [...clients.entries()].find(([, c]) => c.userId === p.id) || [];
        if (otherWs) {
          const you = p;
          const opp = match.players.find((q) => q.id !== p.id);
          safeSend(otherWs, {
            type: 'state',
            tick: tickCounter,
            you: you.toNet(),
            opponent: opp ? opp.toNet() : null,
            bullets: match.bullets.map((b) => b.toNet()),
            elapsedMs: Date.now() - match.createdAt,
          });
          safeSend(otherWs, {
            type: 'matchEnd',
            reason: match.endReason,
            winnerId: match.winnerId,
            yourKills: you.kills,
            opponentKills: opp ? opp.kills : 0,
          });
        }
      }
      // Don't delete immediately so clients can read the final state
      setTimeout(() => matches.delete(match.id), 5000);
      continue;
    }

    const events = match.tick(TICK_MS);
    for (const p of match.players) {
      const [otherWs] =
        [...clients.entries()].find(([, c]) => c.userId === p.id) || [];
      if (!otherWs) continue;
      const you = p;
      const opp = match.players.find((q) => q.id !== p.id);
      safeSend(otherWs, {
        type: 'state',
        tick: tickCounter,
        you: you.toNet(),
        opponent: opp ? opp.toNet() : null,
        bullets: match.bullets.map((b) => b.toNet()),
        elapsedMs: Date.now() - match.createdAt,
      });
      for (const ev of events) {
        if (ev.kind === 'hit' && (ev.shooterId === p.id || ev.victimId === p.id)) {
          safeSend(otherWs, { type: 'hit', ...ev });
        } else if (ev.kind === 'kill') {
          // Both clients see kills
          safeSend(otherWs, { type: 'kill', ...ev });
        } else if (ev.kind === 'respawn' && ev.playerId === p.id) {
          safeSend(otherWs, { type: 'respawn', ...ev });
        }
      }
    }
  }
  tickCounter++;
}

function scheduleNextTick() {
  setTimeout(() => {
    broadcastMatchState();
    scheduleNextTick();
  }, TICK_MS);
}
scheduleNextTick();
console.log('[boot] tick scheduler started, TICK_MS =', TICK_MS);

// ---------------------------------------------------------------------------
// Boot
// ---------------------------------------------------------------------------

httpServer.listen(PORT, () => {
  console.log(`[boot] Everglow AC relay listening on :${PORT}`);
  console.log(`[boot] Open http://localhost:${PORT}/test.html in two tabs to test`);
  console.log(`[boot] Health: http://localhost:${PORT}/health`);
});

process.on('SIGINT', () => {
  console.log('\n[shutdown] closing');
  wss.close();
  httpServer.close();
  process.exit(0);
});
