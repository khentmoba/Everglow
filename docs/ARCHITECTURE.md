# Everglow System Architecture

> Private digital relationship scrapbook for Khent & Clair. React + Vite + Firebase.
> This document is the system-level contract for how Everglow scales, where data
> lives, how it flows, and what the minimal production core must guarantee.

## 1. Goals And Constraints

### Goals

- Keep the couple's private experience (chat, moods, memories, watchlists) fast,
  offline-tolerant, and correct.
- Keep the entire stack small enough for two to five people while leaving a
  clean path to wider audiences: multi-couple tenancy, analytics, regional
  deployments.
- Make every state-changing write enforceable by Firestore security rules and
  every expensive or risky operation (proxies, LLM, push) server-side.
- Make startup deterministic, observable, and versioned.

### Constraints

- Frontend is a React 19 + TypeScript PWA built with Vite and deployed to
  Firebase Hosting. The Windows desktop app (`khentmoba/Everglow-Desktop`)
  wraps the same site.
- Backend is serverless Firebase: Auth, Firestore, Storage, Functions, FCM.
- State lives in small services with `subscribe()`, read through hooks;
  routing is React Router 7; no state library.
- Secrets never ship in source; `assets/env.txt` is local-only and ignored by
  the design below.
- One shared Firestore database, no sharding in the current product stage.

## 2. System Context

```mermaid
flowchart LR
  subgraph Users
    K[Khent browser]
    C[Clair browser]
    G[Guest profiles: Breyan / Octagram]
  end

  subgraph Firebase
    H[Firebase Hosting + CDN]
    A[Firebase Auth]
    F[(Firestore)]
    S[(Storage)]
    FN[Cloud Functions]
    M[FCM]
  end

  subgraph External
    TMDB[TMDB]
    OL[Open Library]
    GLM[Agnes 3.0 Flash LLM]
    LF[Last.fm]
    MD[MangaDex / Bato / Comick / etc.]
  end

  K --> H
  C --> H
  G --> H
  H --> A
  H --> F
  H --> S
  H --> FN
  FN --> F
  FN --> M
  FN --> TMDB
  FN --> OL
  FN --> GLM
  FN --> LF
  FN --> MD
```

The browser talks to Firestore/Storage directly through the Firebase SDK
(real-time reads, offline cache). Cloud Functions exist only where browser
direct access is unsafe, blocked by CORS, secret-bearing, or too heavy:
proxies, AI streaming, push fan-out, and scheduled maintenance.

## 3. Architecture Overview

```mermaid
flowchart TB
  subgraph Client[React PWA]
    UI[Pages / components]
    P[Hooks: useSource, useAuth]
    R[Feature services / repositories]
    CORE[Core: agent mode, app update, prefs]
    SDK[Firebase SDK + local cache]
  end

  subgraph Backend[Firebase]
    RULES[Security rules + indexes]
    FS[(Firestore)]
    ST[(Storage)]
    FX[Cloud Functions]
    SCH[Scheduled jobs]
  end

  subgraph Ops[External]
    UP[Uptime monitors]
  end

  UI --> P
  P --> R
  R --> SDK
  SDK --> FS
  SDK --> ST
  R --> FX
  CORE --> SDK
  CORE --> FX
  FX --> FS
  SCH --> FS
  UP --> FX
  RULES --> FS
```

### Layering rules

1. Pages and components never touch Firestore directly; they read a feature
   service through `useSource` or a `subscribe()` hook.
2. Feature services return plain typed objects, not raw `DocumentSnapshot`.
3. Live sources use `withFirestoreTimeout` (`react/src/core/utils/liveSource.ts`) so a wedged web listener degrades to a
   retry UI instead of an infinite spinner.
4. Writes are validated twice: client-side before dispatch and server-side by
   security rules (shape + ownership).
5. Anything that exposes an API key or needs CORS relief goes through Cloud
   Functions with an allow-list where a URL is involved.

## 4. Component Structure

```text
react/
  src/
    main.tsx                    # agent mode init, service worker, render <App/>
    App.tsx                     # every route, guarded by auth loaders
    core/
      agent/                    # ?agent= jumps, floating HUD, demo fixtures
      router/                   # route helpers, route + scroll memory, error page
      services/                 # firebase, auth, presence, notifications, offline media
      system/                   # logger, prefs, viewport, app update, device/TV mode
      theme/                    # Dusk Petal tokens: colors, typography, layout, motion, paint
      utils/liveSource.ts       # Source<T>, snapshots, withFirestoreTimeout, useSource
    features/<feature>/         # pages, components and services side by side
    shared/
      utils/                    # feature-agnostic helpers
      widgets/                  # global design system (cards, headers, buttons, states)
      widgets/shelf/            # media browsing UI shared by cinema/anime/books
  tools/*.test.mjs              # headless Chrome tests (shell, offline SW, players)
  vite.config.ts                # build + generated service worker (dist/sw.js)

functions/
  index.js                      # thin barrel: wires HTTP functions, triggers, schedules
  media_proxies.js              # CORS/hotlink proxies (manga, anime, gallery, video)
  motchi_*.js                   # AI chat core, tools, memory, schedules, prompts
  catalog.js / anime.js         # catalog + anime proxies
  system_*.js / triggers.js     # presence TTL, push fan-out, ops jobs

firestore.rules                 # single source of truth for access control
firestore.indexes.json          # explicit composite indexes
web/                            # icons, manifest, embed helpers copied into the build
assets/                         # fonts and images (Vite publicDir)
```

### Serverless function taxonomy

| Kind | Functions | Responsibility |
|------|-----------|----------------|
| HTTP proxy | `proxyBookText`, `proxyManga*`, `proxyComick`, `proxyAnimeImage`, `proxyLastfmImage`, `proxyGalleryImage`, `proxyScanlation`, `proxyFetchHtml`, `proxyWatchStream` | CORS/hotlink bypass with host allow-lists |
| AI | `proxyAI`, `proxyAIv2` | SSE streaming, tool execution (Agnes 3.0 Flash) |
| Ops | `health` | public liveness + Firestore reachability |
| Trigger | `onNewChatMessage`, `onNewMood`, `onNewStarDrop`, `onNewWatchlistItem`, `onNewGalleryPhoto`, `onWatchPartyInvite`, `onNewMilestone` | FCM partner notifications |
| Schedule | `motchiDailyDigest`, `motchiNightRecap`, `motchiMoodCheckIn`, `motchiSpecialDayNudge`, `sweepStalePresence` | maintenance + proactive features |
| Debug/admin | `cleanupGallery` | operational tooling (admin-only where destructive) |

### Agent map — where to put things

- New page? `react/src/features/<feature>/<Name>Page.tsx`, plus a route in
  `react/src/App.tsx` (and an agent alias in `core/agent/agentMode.ts`).
- New data call? A service in the same feature folder that returns a `Source`
  or exposes `subscribe()`.
- Shared helper? `core/utils/` or `core/system/` for app-wide;
  `shared/utils/` for feature-agnostic data helpers.
- Shared widget? `shared/widgets/` for the global design system;
  `shared/widgets/shelf/` is media browsing UI shared by cinema/anime/books.
- Colors? `core/theme/colors.ts` (`AppColors`, `withAlpha`). Never hardcode
  hex values in components.
- Server proxy or secret? `functions/` module + export in `index.js`.
  The app never calls third-party APIs directly.

## 5. Data Flow

### 5.1 Session bootstrap

```mermaid
sequenceDiagram
  participant U as User
  participant M as main.tsx
  participant F as Firebase
  participant SW as Service worker

  U->>M: open app
  M->>M: AgentMode.init()
  M->>F: initializeApp (core/services/firebase.ts)
  M->>U: render App: router + auth loaders
  M-->>SW: register /sw.js after load (production only)
  SW-->>U: precached shell for offline starts
```

### 5.2 Passcode -> authenticated session

```mermaid
sequenceDiagram
  participant G as GatewayPage
  participant A as AuthService
  participant FA as FirebaseAuth
  participant FS as Firestore

  G->>A: login with profile + code
  A->>A: POST /api/verifyPasscode
  A->>FA: signInWithCustomToken
  FA-->>A: User
  A->>FS: set users/{uid} {username, updatedAt}
  A->>FS: query users where username == partner
  FS-->>A: partner uid
  A->>A: isCoupleUser / partnerUid resolved
  A-->>G: subscribers notified -> navigate to /dashboard
```

All four profiles' codes are verified server-side (`verifyPasscode` Cloud
Function), which returns a custom token; no credentials ship in the client. The user document is the root of access:
security rules grant sanctuary access to authenticated users with a
`users/{uid}` document.

### 5.3 Realtime couple data (chat, presence, mood)

```mermaid
sequenceDiagram
  participant A as Khent client
  participant FS as Firestore
  participant B as Clair client

  A->>FS: add sanctuary_messages {sender, text, timestamp}
  FS->>B: snapshot listener (persistence cache first)
  A->>FS: set presence/{uid} {isOnline, lastSeen} every 60s
  FS->>B: presence snapshot -> PartnerPresenceIndicator
  B->>FS: add moods {username, moodScore, timestamp}
  FS->>A: latest mood snapshot
```

Writes are optimistic through Firestore's web persistence: the local cache
echoes the write immediately, and the server reconciliation happens in the
background.

### 5.4 AI streaming

```mermaid
sequenceDiagram
  participant C as Motchi client
  participant F as proxyAI / proxyAIv2
  participant DB as Firestore
  participant L as Agnes 3.0 Flash LLM

  C->>F: POST /api/proxyAI(v2) {messages, feature, caller} -> apihub.agnes-ai.com
  F->>DB: fetch user context + ranked memories
  F->>L: stream request with tool schemas
  loop max tool rounds
    L-->>F: content deltas / tool_calls
    F->>DB: execute tool writes (watchlist, mood, notes)
    F->>L: tool results
  end
  F-->>C: SSE reasoning/content deltas
  C->>C: persist conversation locally
```

The client never sees API keys and never receives raw tool state; the server
absorbs tool execution and streams only the final dialogue.

### 5.5 Presence TTL

```mermaid
sequenceDiagram
  participant C as Client
  participant FS as Firestore
  participant S as sweepStalePresence

  C->>FS: isOnline=true, lastSeen=now (60s heartbeat)
  S->>FS: every 2 min: isOnline==true && lastSeen < now-3min
  FS-->>S: stale presence docs
  S->>FS: isOnline=false, sweptAt=now
```

This closes the "ghost online" gap left when a browser tab closes without
logging out.

## 6. API Design

### 6.1 Firestore as the primary API

Firestore is the system of record and the real-time API. Queries are bounded
and documented by collection:

| Collection | Read contract | Write contract |
|------------|---------------|----------------|
| `users/{uid}` | authenticated, own or couple-shared docs | self-write only via `_syncUserDoc` |
| `presence/{uid}` | authenticated | self-write heartbeat; sweeper owns offline flip |
| `moods` | authenticated, latest per user via `username + timestamp desc` | authenticated create; validated fields |
| `sanctuary_messages` | authenticated couple user | authenticated couple user |
| `watch_party_rooms/{roomId}` | host or partner | host/partner, fixed uid pair |
| `voice_rooms/{roomId}` | caller or callee | caller/callee, bounded SDP strings |
| `config/{docId}` | authenticated read | server/admin only |
| `users/{uid}/progress/{docId}` | owner only | owner only |

Every query the client makes must be covered by a single-field auto-index or an
explicit composite index in `firestore.indexes.json`. The current explicit
indexes cover `bucket_list`, `moods`, and `presence`; add a new entry whenever
`where` + `orderBy` meet.

### 6.2 Cloud Functions REST surface

Convention: `POST`/`GET` JSON, CORS preflight accepted, optional Firebase ID
token verified when present, allow-listed upstream hosts, bounded timeouts.

| Endpoint | Method | Request | Response |
|----------|--------|---------|----------|
| `/api/health` | GET | none | `{status, service, version, time, uptimeSeconds, checks}` |
| `/api/proxyAI` | POST | `{messages, feature}` | SSE stream of `{reasoning, content}` deltas |
| `/api/proxyBookText` | POST | `{urls: string[]}` | `{text, usedUrl, attempted}` |
| `/api/proxyMangaImage` | GET | `?url=` | proxied image bytes, `Cache-Control: max-age=600` |
| `/api/cleanupGallery` | POST | `{confirm: true}` | `{deleted}` (Khent only) |

Errors follow `{error: string}` with conventional status codes: `400` shape,
`401` token, `403` host/owner, `405` method, `502` upstream, `503` degraded.

### 6.3 Scheduled jobs

- `sweepStalePresence`: every 2 minutes, Firestore-indexed stale sweep.
- `motchiDailyDigest` / `motchiNightRecap` / `motchiMoodCheckIn` /
  `motchiSpecialDayNudge`: Asia/Manila timezone proactive features.

### 6.4 External provider contracts

| Provider | Use | Key handling |
|----------|-----|--------------|
| Agnes 3.0 Flash (apihub.agnes-ai.com) | AI chat — 512K context, 120K input budget, 50+ tool calls, thinking | server-side AGNES_API_KEY only |
| TMDB | cinema/anime metadata | server-side via `proxyTmdb` (authenticated, ID-token required) |
| Open Library | book text | `proxyBookText` server fetch |
| MangaDex / Bato / Comick / Mangakakalot / Mangasee123 | manga catalog + images | allow-listed host proxies |
| Last.fm | music status | server-side via `proxyLastfm` (authenticated) |

### 6.5 Hidden contracts (read before changing these)

Nothing in the type system ties these together; each one broke or cost a
long search once.

- **Video streams** go through the Cloudflare Worker
  (`everglow-stream…workers.dev`, `cloudflare/`; origins in
  `react/src/features/cinema/playerServices.ts` and
  `react/src/features/anime/animexWatchConfig.ts`). `proxyVideoStream`,
  `proxyEmbed`, and `onWatchPartyInvite` were removed on purpose (#527);
  `functions/test/media_proxy_html.test.js` keeps them gone. Check
  `git log -S <name>` before rebuilding something that looks missing.
- **Legacy milestone photos:** Firestore still stores
  `assets/images/milestones/<file>`; `repairLegacyMilestoneImageUrl` in
  `react/src/features/dashboard/milestoneService.ts` maps it to Storage
  `milestones/legacy/<file>`. Keep that mapping when touching the Living Archive.
- **Desktop app bridge:** the Tauri app injects
  `window.__everglowDesktopVersion` and `window.__everglowCheckForUpdates`
  (Everglow-Desktop `src-tauri/src/website_bridge.rs`);
  `react/src/features/dashboard/DesktopAppPage.tsx` reads those exact names.
  See `docs/DESKTOP_APP.md`.
- **OAuth scopes:** adding a Spotify scope (`jukeboxService.ts`) does not
  upgrade tokens already linked. Ship a re-link path with the new scope.
- **Low-end gate:** `reduceAmbientMotion` (`react/src/core/system/device.ts`)
  turns ambient motion off on 4-core machines, which includes the CI runner,
  and under 600px. Features that must still move or hover belong outside that
  gate; test them with `?lowend=1`.

## 7. Database Schema

All timestamps are Firestore server timestamps; IDs are client-created or
`add()` generated. The schema below is the MVP set plus the couple-only rooms
that already exist.

### `users/{uid}`

| Field | Type | Notes |
|-------|------|-------|
| `username` | string | profile key: `khentsgdz`, `clairjassen`, `breyan`, `octagram` |
| `updatedAt` | timestamp | server set on every login sync |

### `presence/{uid}`

| Field | Type | Notes |
|-------|------|-------|
| `isOnline` | bool | client heartbeat, sweeper flips false |
| `isDoodling` | bool | canvas activity flag |
| `lastSeen` | timestamp | TTL input |
| `lastDoodleAt` | timestamp | idle window input |
| `username` | string | display |
| `updatedAt`, `sweptAt` | timestamp | last write / sweeper write |

Index: `isOnline ASC, lastSeen ASC` (sweeper query).

### `moods/{moodId}`

| Field | Type | Notes |
|-------|------|-------|
| `username` | string | partner lookup key |
| `uid` | string | optional auth uid for resilient partner resolution |
| `moodScore` | int | 1-5 |
| `moodEmoji` | string | display emoji |
| `timestamp` | timestamp | date-scoped |
| `date` | string `YYYY-MM-DD` | scheduled digest grouping |

Index: `username ASC, timestamp DESC` (latest mood query).

### `sanctuary_messages/{messageId}`

| Field | Type | Notes |
|-------|------|-------|
| `sender` | string | username |
| `senderUid` | string | auth uid |
| `text` | string | bounded by client validation |
| `timestamp` | timestamp | ordering key |

### Couple rooms

`watch_party_rooms/{roomId}` (host/partner uid pair fixed; auto ids for
named rooms, plus the legacy deterministic sorted-uid id),
`watch_party_chats/{roomId}/messages/*`,
`voice_rooms/{roomId}` (caller/callee, bounded SDP), and
`temporary_chats/{roomId}` all carry the couple's uid pair and are never
reassignable. Named rooms use Firestore auto ids; the legacy room keeps the
deterministic sorted-uid join so existing chats and calls still resolve.

### Shared scrapbook collections

`starlight_jar`, `our_cinema`, `watch_list`, `milestones`, `gallery`,
`calendar_events`, `bucket_list`, `garden_stats`, `canvas_strokes`,
`live_canvas`, `ai_memories`, `notes`, `read_list`, `manga_library`,
`academy_questions`, `active_matches`, `music_status`, `garden_stats`,
`guardian_messages`, `date_ideas`, `progress` — authenticated access with
per-owner rules where subcollections exist.

## 8. Caching Strategy

### Layer 1: Firebase Hosting CDN

`react/dist` hashed assets (`*.js`, `*.css`, fonts, icons) are served with
long-lived immutable caching. `index.html`, `sw.js`, and `version.json` are
`no-cache` so new builds take effect immediately (`firebase.json` headers).

### Layer 2: Service worker shell

The generated `sw.js` precaches the app shell so the app starts offline.
Firestore uses its default in-memory cache; `withFirestoreTimeout` turns a
hung listener into a retry state instead of a frozen screen.

### Layer 3: Local device state

`localStorage` (`core/system/prefs.ts`) keeps the current profile
(`current_user_name`) and small UI preferences. This is the only cross-restart session state; everything else
is derived from Firestore.

### Layer 4: Function response caching

| Surface | Policy |
|---------|--------|
| Manga/anime image proxies | `Cache-Control: public, max-age=600` |
| Gallery proxy | `max-age=3600` |
| Catalog proxies | `max-age=60` |
| Health | `no-store` |
| AI streams | never cached |

### Layer 5: In-process caches

- Motchi persona document cache with TTL.
- AI context cache (30s TTL) to avoid redundant Firestore reads on rapid
  messages.

### Invalidation rules

- Content that changes per user (presence, moods, chat) is never HTTP-cached.
- Build-versioned assets never need invalidation; `sw.js` regeneration stamps
  the build version.
- `sweptAt` timestamps let ops verify presence TTL without guessing.

## 9. Security Model

1. **Auth boundary**: anonymous sessions are never valid for app reads
   (`isNotAnonymous` is required by every rule); the gateway forces a real
   login, and couple features additionally require a `users/{uid}` document.
2. **Ownership**: `users/{uid}/*` and `presence/{uid}` are self-scoped.
3. **Couple pair**: rooms/chat are read-write only for the two uids encoded in
   the document; uid pairs are immutable after creation.
4. **Shape validation**: room state enums and bounded SDP strings are enforced
   in rules to prevent payload abuse.
5. **Server-only secrets**: LLM keys, FCM keys, and proxy secrets live in
   Functions environment/config, never in web assets.
6. **URL allow-lists**: every proxy validates protocol `https:` and host
   suffix before fetching.
7. **Destructive ops**: `cleanupGallery` requires an ID token and the Khent
   profile.

## 10. Scaling And Reliability

### Current stage (2-5 users)

- Single Firebase project, one Firestore database, single region.
- Rules and indexes are source-controlled; deploys are atomic through CI.
- Presence TTL is enforced server-side, removing the most common stale-state
  bug.

### Multi-couple path

- Add `coupleId` to `users` and namespace shared collections by
  `couples/{coupleId}/{feature}/{docId}`.
- Move every security rule from "any authenticated user" to
  `coupleId in get(/users/{uid}).data.coupleIds`.
- Replace username-based partner lookup with a `users` query on `coupleId`.
- Keep `sanctuary_messages` partitioned by `coupleId` to avoid one hot chat
  collection.

### Load path

- Keep heavy reads (watchlists, catalog) in Firestore/Storage; push AI and
  proxying to Functions/Cloud Run.
- Add Firestore query limits and pagination before any screen can exceed a few
  thousand documents.
- When read amplification outgrows Firestore, introduce a read-model cache
  (e.g. Redis/Memorystore or a derived `digests` collection) written by
  scheduled functions.

### Reliability guarantees

- Startup never blocks on health, notifications, or remote fonts.
- Every Firestore stream has a timeout and a retry surface.
- Scheduled maintenance (`sweepStalePresence`) is idempotent: flipping an
  already-false document is a no-op.
- Known Firestore web race conditions are filtered from the unhandled-error
  path so real failures stay visible.

## 11. Observability And Deployment

### Deploy pipeline

`push main -> typecheck + build react/dist (with sw.js) -> functions verify ->
deploy functions + rules + storage -> deploy Hosting -> verify site 200`
(`.github/workflows/deploy.yml`).

### Health monitoring

- Public `GET /api/health` returns service identity, version, uptime, and a
  Firestore reachability check.
- Uptime monitors should alert on non-200 or `status != ok` for two
  consecutive checks.

### Error visibility roadmap

Current release builds suppress unhandled errors by design; the immediate
follow-up is wiring `Logger` error sinks to a production reporter (Sentry, or an
`error_reports` Firestore collection) and uploading source
maps in CI.

### Rollback

Hosting: roll back to the previous release in the Firebase Hosting console,
or rebuild `react/dist` from the previous tag and redeploy.
Functions: `firebase deploy --only functions` from the previous tag. Rules:
revert `firestore.rules`/`firestore.indexes.json` and redeploy
`--only firestore`.

## 12. Minimal Production Version

The core every feature depends on:

1. **Deterministic startup**: `react/src/main.tsx` initialises agent mode,
   registers the service worker, and renders the router; auth state comes
   from `core/services/auth.ts`.
2. **Version source of truth**: `react/package.json`, mirrored by the
   Functions `APP_VERSION` constant (`functions/common.js`); the health
   endpoint reports it.
3. **Health contract**: `GET /api/health`.
4. **Presence TTL**: `sweepStalePresence` scheduled job with pure, tested
   staleness logic (`functions/system_core.js`).
5. **Query schema**: explicit composite indexes for `moods` and `presence`
   sweeper queries.

### Verification

```text
npm --prefix react run typecheck
npm --prefix react run build
npm --prefix react test
cd functions && npm run verify
```

## 13. Runbook Cheat Sheet

| Task | Command |
|------|---------|
| Local app | `npm --prefix react run dev` |
| Typecheck | `npm --prefix react run typecheck` |
| Tests | `npm --prefix react test` (after a build) |
| Functions lint | `cd functions && npm run lint` (CI adds `-- --max-warnings=25`) |
| Functions tests | `cd functions && npm test` |
| Health check | `curl https://everglow-1c6db.web.app/api/health` |
| Deploy everything | `deploy.ps1` |
| Deploy rules only | `firebase deploy --only firestore:rules,firestore:indexes` |
