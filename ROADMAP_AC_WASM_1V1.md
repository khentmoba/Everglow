# AssaultCube WebAssembly 1v1 Multiplayer — Roadmap

## Status

**This session** shipped a working solo AssaultCube in Everglow:
- Real C++ AC engine running in the browser via WASM (Gibgoyt/assaultCubeWasm prebuilt)
- Mobile touch controls (dual virtual joysticks + fire + jump + menu + reload)
- Force-landscape orientation + immersive sticky system UI
- Firestore presence (Khent ↔ Clair see each other online in the play zone)
- Firestore game stats (solo & 1v1 — best kills, matches played)

**1v1 is wired through the UI but not yet live in the WASM engine itself.** The
mode select offers a 1v1 option, but tapping it currently boots the same solo
(bots) flow. Wiring actual real-time Khent-vs-Clair gameplay through the
real AC engine requires work outside Flutter, summarised below.

## Why real 1v1 isn't free

The prebuilt AC WASM port is **offline single-player only**. The original C++
AC has a separate `server.cpp` binary that runs the authoritative game state
and clients connect to it over ENet (UDP). The WASM port replaces ENet with
a stub (`enet_stub.cpp`) and uses an in-process `localconnect()` call to talk
to an embedded single-player server, so bots are the only opponent.

Browsers can't open raw UDP sockets, so the WASM client cannot talk to a real
AC server directly. We have to insert a translation layer.

## Path A — Fastest (recommended): WebSocket transport + ENet relay

```
┌────────────┐  WSS  ┌──────────────────┐  ENet/UDP  ┌────────────────┐
│ Flutter AC │──────▶│ Node.js relay    │───────────▶│ Native AC srv  │
│ WASM client│       │ (Fly.io / CF Wkr)│            │ (Linux binary) │
└────────────┘       └──────────────────┘            └────────────────┘
        │                                                     ▲
        └─────── Firestore (lobby, match presence, stats) ───┘
```

### Components

1. **C++ server** — build `source/src/server.cpp` for Linux with a real
   network stack (clang++ on Ubuntu is fine, no Emscripten needed).
   Emscripten isn't required here. Output: `ac_server` binary. Run on
   `fly.io` or a $5/mo VPS. ~1 day.

2. **ENet ↔ WebSocket relay** — small Node.js process that accepts
   WebSocket connections from the browser and forwards them as ENet
   packets to the AC server. Each browser = one ENet "peer". The relay
   is dumb (just a port forwarder). ~1-2 days.

3. **Replace the WASM ENet stub** — rewrite `enet_stub.cpp` in the
   community port to open a WebSocket instead of a UDP socket. The
   ENet wire format is small (~10 bytes header) and easy to
   reimplement. Or: write a thin shim that exposes only the ENet
   functions AC actually calls (`enet_host_create`,
   `enet_host_connect`, `enet_host_service`, `enet_peer_send`) and
   translate them to WebSocket frames. ~1-2 weeks.

4. **Lobby & matchmaking** — Firestore already has presence
   (`ac_web_presence`); add a `ac_web_matches` collection for
   matchmaking state (hostId, participantId, status, serverEndpoint).
   Flutter picks the lowest-ping relay, prompts the other player, both
   clients connect. ~2-3 days.

5. **Stats & result sync** — extend `AcStatsService` with a
   `recordOneVOneMatch` flow that knows who won (use AC's scoreboard
   in the WASM client to detect match end, push to Firestore). ~1 day.

### Total estimate

**3-4 weeks** for one developer comfortable with C++ and Node.

## Path B — Faster but limited: "parallel" 1v1

Skip the real AC engine. Run two separate solo WASM instances (one per
player), each against bots. Firestore syncs scores in real time so each
player sees the other player's current match progress. UI labels it
"parallel 1v1 — beat Clair's score before time runs out."

Pros: ships in a day. Cons: not actually playing the same match.

## Path C — Drop 1v1

Mark the real AC 1v1 option "coming soon" indefinitely, keep solo play
working, and use the existing native AssaultZone 1v1 (Firestore-based,
already shipped in v2.0.0) for Khent ↔ Clair 1v1 in the meantime.

## What's in the codebase right now

- `lib/features/play_zone/assault_cube_web/` — Dart integration
  (presence, stats, input bridge, screen, touch controls)
- `web/ac_wasm/ac_client_wasm.{html,wasm,js,data}` — bundled for deploy
- `scripts/copy_ac_wasm.ps1` — refresh the bundled files from the
  upstream clone when a new prebuilt is released

## Where to start

Path A is the right long-term answer. The relay server is a good first
step (2-3 days) because:
- it's a real, deployable artifact
- it can be tested standalone with any ENet client
- it unblocks the harder WASM-side work

Open the relay project as a sibling repo (`everglow-ac-relay`) so it
deploys independently of the Flutter app's Firebase Hosting.
