# Changelog

Every Everglow release, newest first. Each version also has a page at
`https://github.com/khentmoba/Everglow/releases/tag/vX.Y.Z`.

Releases are manual and curated — see "Releases" in `AGENTS.md`.

## [6.1.0] - 2026-09-09 - The Glow-Up Update

Two months of polish since v6.0.0: Mochi grew from a dozen tools to 50+,
Cinema moved closer to Netflix, XP now rewards everyday moments, and the
whole app got faster on phones.

### New: Journal

- Shared couple journal with locked/private entries and tags.
- Mochi can search entries in two stages and read them back unabridged.

### Mochi AI grows up (12 → 50+ tools)

- New tools: web search and page reading, gallery / garden / canvas
  awareness, memory pin / edit / delete, relationship insights, today
  recap, memory trivia, watchlist and book-progress management, and more.
- Study PDFs right inside chat; Notebook-style Study space in the Academy
  with session history and an interactive quiz + flashcards canvas.
- Cozy chat + study redesign, new sidebar with hub shortcuts, stop button,
  stable suggestion chips, and user avatars.

### Cinema, closer to Netflix

- Remind-me bell for unreleased titles, Netflix-style Top-10 numerals,
  long-press touch previews on posters, and hero age chips on phones.
- Player episode list unified with the drawer tiles; continue-watching
  entries are now removable.
- Player overhaul: no-ads providers first, safer sandboxed iframe,
  share-to-Discord watch-party button.
- Removed Mochi's Picks row so home screens stay focused.

### Anime

- Skip Opening / Skip Ending buttons from AniSkip, auto-appearing on Videasy.
- AnimeX home polish, richer hover details, and hero fullscreen sync fix.

### XP rewards everyday love

- Faster curve: 200 XP per level.
- Auto-XP for mood check-ins, journal entries, garden care, and star drops.
- XP for music listens, plays, and dedications.

### Fresh coats of paint

- Redesigned Play Zone and Academy hubs; Mochi sidebar and chat overhaul.
- Dashboard marquee edges fade softly; passcode screen copy simplified.

### Faster on phones

- Dashboard scroll-jank fix, Coming Up auto-retry on first load, shared
  calendar stream with debounced cold-start listeners.
- Smaller downloads: font weights trimmed, table-tennis duplicates gone
  (49 MB of dead game files removed from deploys), guardian 3D cat
  4.0 MB → 283 KB with instant placeholder.
- Thumbnails backfilled on Watched / Finished shelves, auto-retry after
  transient failures, CanvasKit black-thumbnail fix, web console cleanup.

### More reliable

- Crash guards with tests for gallery, chat, garden, and mood parsing.
- Jukebox Top 10 and leaderboard stay visible through Last.fm hiccups.
- Passcode screen tells connection errors apart from wrong codes.
- Firestore rules hardened across collections.

### Under the hood

- Cloud Functions split into focused modules; Mochi eval gate runs on PRs.
- Web-lite experiment reverted — the Flutter build serves again.
- Service worker stamped with the Flutter engine revision; dead
  AssaultCube game and retired ac-relay voice server deleted (watch-party
  voice signals through Firestore).

## [6.0.0] - 2026-07-13 - The Relationship Hub Update

Three brand-new shared features, a Daily Bloom overhaul, push
notifications, AI function calling, and a dashboard redesign.

- **Bucket List** — shared list with 6 categories and
  Wished → Planned → Completed tracking.
- **Calendar** — shared calendar with date nights, anniversaries,
  reminders, and recurring events.
- **Gallery** — shared photos with upload, captions, tags, and viewer.
- **Daily Bloom overhaul** — 5 plant types with unique painters, seasonal
  bonuses, shared garden view, and weather overlay.
- **Push notifications** — FCM with topic subscriptions and in-app toasts.
- **Mochi function calling** — first 12 tools (watchlist, starlight jar,
  moods, movie / book / anime search, weather, reminders, and more).
- **Dashboard overhaul** — calendar and gallery previews, relationship
  timeline, countdowns, and creator modal.

## [5.3.0] - 2026-06-14 - Anime Embeds

- Anime embed provider switching and VidSrc integration.
- AniList GraphQL fix for rich anime details.

## [5.2.0] - 2026-06-14 - Rich Anime Details

- AniList (GraphQL) + Jikan (REST) anime details: characters, staff,
  episodes, trailers, and recommendations.
- Anime search modal; episode drawer routes anime items through AniList.
- Cinema UI improvements.

## [5.1.0] - 2026-06-14 - Anime Browse

- Anime Browse tab with 25+ filterable category chips.
- Curated Anime Home sections with hero carousel.
- `proxyMangaDex` Cloud Function fixes empty manga states on web.
- Play Zone HUD refactored to shared overlay widgets.

## [5.0.0] - 2026-06-13 - Anime Arrives

- Dedicated Anime screen (Home / Library / Search) with TMDB trending.
- MangaDex image proxy; anime dashboard preview marquee.

## [4.0.0] - 2026-06-14 - Play Zone Polish

- Game boot and gesture polish across Table Tennis World Tour,
  Fun Race 3D, and HexGL Drift.
- Consolidated manga reader, Play Zone HTML games, and UI refinements.

## [3.4.0] - 2026-06-14 - Manga Reader

- Full manga reader: MangaDex search, cinematic detail drawer, custom
  reader with zoom and chapter navigation.
- Masked Special Forces 3D shooter in the Play Zone.
- Cloud Function CORS proxy; episode drawer polish.

## [3.3.0] - 2026-06-13 - Play Zone Games

- Table Tennis World Tour, Fun Race 3D (solo + 1v1 lobby), unified match
  lobbies.
- Cinema shared watchlist consolidation; dashboard marquee.

## [3.2.0] - 2026-06-13 - Our Books

- Book discovery via Open Library with in-app reader (Night / Sepia /
  Light themes, progress persistence).
- Instant carousel trailers; mobile trailer polish.

## [3.1.0] - 2026-06-13 - Live & Cinematic

- Live presence: 15 s heartbeat with online / doodle freshness windows.
- Hover-to-play looping trailers on posters.
- Our Cinema glass UI overhaul.

## [3.0.0] - 2026-06-13 - Cinematic Cinema

- Cinematic Dark Luxury cinema rebuild: floating pill nav, hero carousel,
  episode drawer.
- Piano Tiles engine rewrite; Breyan cinema-only access.

## [2.1.0] - 2026-06-13 - Drift & Melody

- HexGL Drift 3D racing with ghost replays.
- Melody Tiles song selection.

## [2.0.0] - 2026-06-13 - Mobile & Cleanup

- Melody Tiles rhythm game with XP awards.
- Mobile optimization and bloat cleanup; cinema refactoring.

## [1.5.3] - 2026-06-13 - Real Iframe Fix

- Root-cause sandbox fix: plain iframe player, popup-ad blocking sandbox.
- Provider cleanup; spinner tied to native load event.

## [1.5.2] - 2026-06-12 - True PH Rankings

- Philippines trending shows what Filipinos actually watch (watch-region
  ranking instead of locally-produced filter).

## [1.5.1] - 2026-06-12 - Sandbox Hardening

- "Please Disable Sandbox" fix across providers; cinema and UI polish.

## [1.5.0] - 2026-06-13 - Cinema Overhaul

- Genre browsing, cast and reviews, trending carousel, PH rankings.
- Sandbox bypass script for streaming providers.

## [1.4.0] - 2026-06-12 - Multi-Provider Video

- 17 streaming providers with ad-load ratings and per-episode URLs.
- Episode drawer debuts.

## [1.3.0] - 2026-06-12 - Racing Touch UI

- Racing auto-respawn; pedal-style gas / brake, boost ring, steering pad.

## [1.2.0] - 2026-06-12 - Midnight Drive

- Playable 3D desert racing game (React Three Fiber + physics).

## [1.0.0] - Untagged - First Light

- Original private builds for Khent and Clair: gateway, dashboard,
  heartbeat, guardian, sanctuary chat, daily bloom, date randomizer.
  (Version tags start at v1.2.0.)
