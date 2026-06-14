# Changelog

All notable changes to **Everglow** are documented in this file.
Everglow is a private Flutter Web scrapbook for Khent and Clair, so this changelog is
the canonical source for everything that has shipped.

Format: `[version] — YYYY-MM-DD`
Conventions: 🚀 Features · 🐛 Bug Fixes · ⚡ Performance · 🔒 Security · 📝 Docs · 🧹 Chores · ⚠️ Breaking

---

## [5.3.0] — 2026-06-14

### 🚀 Features
- **Anime Embed Support in Video Player**: `VideoPlayerScreen` now supports MAL-id-based anime embeds via VidSrc and VidSrc CC alongside the existing TMDB-based Videasy provider. The player auto-detects anime items and serves the appropriate embed source.
- **Provider Switching Dropdown**: Anime items get a live provider switcher (VidSrc / VidSrc CC) in the header badge—a `PopupMenuButton` lets users switch embed sources on the fly without leaving the player.
- **`VideoProvider` Model**: New data class encapsulating embed source configuration (`id`, `name`, `shortName`, `note`, `movieUrl`, `tvUrl`) enabling easy addition of new providers.
- **`isAnime` / `malId` in VideoPlayerScreen**: New optional parameters so callers can explicitly mark anime playback and pass a MAL id for correct embed URL construction.
- **EpisodeDrawer Anime Routing**: `_playMovie()` and `_playEpisode()` now pass `isAnime` and `malId` to `VideoPlayerScreen` when the item is anime-sourced, ensuring anime content routes to the correct embed provider.

### 🐛 Bug Fixes
- **AniList GraphQL Variable Mismatch**: Fixed `'malId': malId` → `'idMal': malId` in `AniListService._fetchMediaByAnilistId()`. The GraphQL query variable name must match the parameter in the query definition (`$idMal`), not the `Media.idMal` field name. This was silently returning null `Media` objects, causing anime taps to show no details.

### 📝 Docs
- Updated CHANGELOG and version for v5.3.0.

### ⚠️ Breaking Changes
- None. v5.3.0 is fully backward-compatible with v5.2.0 data.

---

## [5.2.0] — 2026-06-14

### 🚀 Features
- **AniList/Jikan Rich Anime Details**: New `AniListService` and `JikanService` providing deep anime metadata—synopsis, scores, studios, genres, voice actors, staff, and streaming links—shown in the episode drawer for anime items. AniList GraphQL queries fetch by TMDB cross-referenced ID or MAL id; Jikan REST API serves as the fallback source.
- **Anime Search Modal (Jikan)**: New `JikanSearchModal` with debounced querying, MAL-id resolution, and "add to watchlist" flow for anime titles. Search results show cover art, type, episodes, score, and status badges.
- **MediaItem Model Expansion**: Added `anilistId`, `malId`, `jikanSynopsis`, `jikanScore`, `jikanRank`, `jikanPopularity`, `jikanEpisodes`, `jikanStatus`, `jikanType`, `jikanStudios`, `jikanGenres`, `jikanUrl`, and `anilistStreamingLinks` fields with full Firestore round-trip serialization.
- **Cinema Screen Rewrite**: Major refactor of `CinemaScreen` for unified anime/general media browsing with improved layout and state management.
- **Episode Drawer Overhaul**: Rich anime details section in the episode drawer showing synopsis, score ring, rank, popularity, studio badges, genre chips, and streaming link pills when viewing an anime item.

### 🐛 Bug Fixes
- None.

### 📝 Docs
- Updated CHANGELOG, README, and version for v5.2.0.

### ⚠️ Breaking Changes
- None. v5.2.0 is fully backward-compatible with v5.1.0 data.

---

## [5.1.0] — 2026-06-14

### 🚀 Features
- **Anime Browse Tab**: Brand-new fourth tab on `AnimeScreen` with filterable category chips grouped into By Format, By Genre, By Status, and Discovery. Each chip lazily fetches its results inline via `TMDBService.discoverAnime()`. Categories include Series, Movies, OVAs, 9 genre chips (Action, Romance, Comedy, Slice of Life, Fantasy & Isekai, Sci-Fi & Mecha, Horror & Thriller, Sports, Mystery), Currently Airing, Completed, New Releases, Trending Now, Popular All Time, Top Rated, Hidden Gems, and Editor's Picks.
- **Anime Home Tab Curated Sections**: Replaced single "Trending Anime" carousel with 8 independent sections: Trending Now, Currently Airing, Top Rated, New Releases, Popular All Time, Hidden Gems, Editor's Picks, and the user's own queue. Each section loads independently with its own shimmer placeholder.
- **Anime Hero Carousel**: Trending Now section now uses a larger hero-style `PageView` carousel with backdrop image, gradient overlay, "TRENDING" badge, title, and year overlay.
- **`TMDBService.discoverAnime()`**: Refactored `fetchTrendingAnime()` into a generic `discoverAnime()` with full query-param support (`sortBy`, `withGenres`, `withKeywords`, `withStatus`, `airDateGte/Lte`, `firstAirDateGte/Lte`, `voteCountGte/Lte`, `voteAverageGte`, `page`). Adds `discoverAnimeMovies()` for anime movies via `/discover/movie`.
- **`anime_categories.dart`**: New data layer defining `AnimeCategoryOption` and `AnimeCategoryGroup` enums with self-contained fetcher closures. Editor's Picks loads 21 hand-curated TMDB IDs via `fetchMediaDetails()`.
- **`proxyMangaDex` Cloud Function**: New Firebase Cloud Function that proxies `api.mangadex.org` requests server-side, bypassing CORS restrictions on Flutter web. Accepts `?path=<encoded api path>` and passes through the JSON response with permissive CORS headers. Only `api.mangadex.org` host is allowed.
- **MangaDex Catalog Proxy**: `MangaDexService` now routes all API calls (`searchManga`, `searchMangaSimple`, `getTrendingManga`, `getMangaDetails`, `getChapterPages`, `getMangaTags`, `fetchChapterFeed`) through the new `proxyMangaDex` Cloud Function via `_proxied()`. Fixes the "Nothing here yet." empty-state bug on Flutter web where the browser dropped MangaDex API responses due to missing CORS headers.
- **`WebOverlayButton` / `WebOverlayTextButton` / `WebOverlayPill` Widgets**: New reusable HUD widgets rendered as real DOM elements (`<button>` / `<div>`) via `HtmlElementView` so they sit ABOVE sibling iframes in the browser z-order and receive clicks. Non-web platforms fall back to standard Flutter `GestureDetector` widgets.
- **Play Zone HUD Refactor**: `HexGLGameScreen`, `FunRace3DGameScreen`, `FunRace3DOneVOneGameScreen`, and `TableTennisGameScreen` all replaced their local `_hudButton()` implementations with the shared `WebOverlayButton` / `WebOverlayTextButton` / `WebOverlayPill` widgets. Fixes unclickable close/restart/finish buttons on web when stacked over iframe platform views.
- **Open Library Service Emulator Support**: `BookProxyURL` now supports `--dart-define=USE_FIREBASE_EMULATOR=true` and `--dart-define=BOOK_PROXY_URL=...` for local Functions emulator development. Falls back to Open Library work page (HTML, browser-only) when no plain-text source is available.
- **BookItem Firestore Round-Trip**: `readSourceUrl` and `readSourceLabel` are now persisted in Firestore, so the reader can locate the text source after a read/write round-trip without re-deriving from `iaId`/`workKey`. Legacy documents fall back to `deriveReadSourceUrl()`.
- **CI/CD Functions Deployment**: `.github/workflows/deploy.yml` now includes a `Setup Node.js`, `Install Functions dependencies`, and `Deploy Cloud Functions` step before Hosting deploy, so `proxyMangaDex` (and future functions) are deployed on every push to `main`.

### 🐛 Bug Fixes
- **MangaDex CORS on Web**: Previously the browser dropped all MangaDex API responses because `api.mangadex.org` doesn't send `Access-Control-Allow-Origin` headers. The new `proxyMangaDex` Cloud Function forwards requests server-side, restoring manga search, trending, chapter loading, and tag browsing on Flutter web.
- **Play Zone HUD Buttons Unclickable on Web**: Close, restart, and "I FINISHED!" buttons stacked over `HtmlElementView` iframes were consumed by the iframe before Flutter's pointer dispatch. The new DOM-based `WebOverlayButton` family renders buttons as real HTML elements that sit above the iframe z-order and receive click events correctly.

### 📝 Docs
- Updated CHANGELOG, README, and version for v5.1.0.

### ⚠️ Breaking Changes
- None. v5.1.0 is fully backward-compatible with v5.0.0 data. All new Firestore writes are additive (`readSourceUrl` / `readSourceLabel` on `book_list` / `our_books` documents).

---

## [5.0.0] — 2026-06-14

### 🚀 Features
- **Anime Screen**: Brand-new dedicated `AnimeScreen` with three-tab layout (Home / Library / Search). Home tab shows trending anime from TMDB filtered by Japanese language + Animation genre. Library tab streams the couple's combined anime catalog split into "To Watch" / "Watched" rails with color-coded chips. Search tab debounces TMDB querying with anime-scoped results.
- **Anime Dashboard Preview**: New `AnimePreview` widget on the dashboard — a constant-speed marquee carousel of the watched anime catalog. Shows the couple's combined anime list for Khent and Clair, falling back to the current user's own list for cinema-only accounts.
- **TMDB Anime Detection**: `TMDBService` now auto-detects anime via `_detectAnime()` by checking `original_language == 'ja'` and Animation genre (16) on fetch. New `fetchTrendingAnime()`, `isAnimeByTmdbId()`, `getAnimeWatchListStream()`, `getCoupleAnimeStream()` methods. Watchlist items carry a persisted `isAnime` flag for accurate filtering without re-fetching.
- **MediaItem `isAnime` Field**: Added `isAnime` boolean to the `MediaItem` model with full `toFirestore` / `fromFirestore` / `copyWith` / JSON serialization support.
- **Episode Drawer Anime Detection**: Auto-detects anime via `TMDBService.isAnimeByTmdbId()` when saving to watchlist, passing `isAnimeOverride` to ensure accurate flagging.
- **MangaDex Image Proxy**: New Cloud Function `proxyMangaImage` that proxies MangaDex at-home image server URLs, bypassing CORS/hotlink protection. Validates host against `uploads.mangadex.org` and `*.mangadex.network` / `*.mangadex.org`.
- **Manga Library Back Navigation**: Added back arrow button on `MangaLibraryScreen` when `Navigator.canPop` is true.
- **HexGL Auto-Boot**: `HexGLGameScreen` sets `_iframeTouchGuard = false` on boot ready message, clearing start hint automatically.

### 🐛 Bug Fixes
- None.

### 📝 Docs
- Updated CHANGELOG, README, and version for v5.0.0.

### ⚠️ Breaking Changes
- None. v5.0.0 is fully backward compatible with v4.0.0 data — all new Firestore writes include an additive `isAnime` field.

---

## [4.0.0] — 2026-06-14

### 🚀 Features
- **Play Zone Start Gestures**: Expanded gesture recognition areas across full screen overlays for Table Tennis, Fun Race 3D, and HexGL, facilitating smoother booting.
- **Release Automation**: Prepared configuration metadata and deployment hooks for automatic Firebase deployment.

### 📝 Docs
- Updated CHANGELOG, README, and version for v4.0.0.
- New `RELEASE_NOTES_v4.0.0.md` detailing the transition from v3.2.0 to v4.0.0.

---

## [3.4.0] — 2026-06-14

### 🚀 Features
- **Manga Dex Integration**: Brand-new `MangaLibraryScreen` and custom `MangaSearchModal` interacting with the MangaDex API.
- **Manga Reader**: High-fidelity vertical and side-by-side reading screens with chapter transition navigation.
- **Manga Details Drawer**: Sliding card showing covers, summaries, tag lists, and direct reading routes.
- **Manga Dashboard Preview**: New preview card on the dashboard showing recently read/trending manga.
- **Masked Special Forces Embed**: Integrated 3D WebGL shooter game "Masked Special Forces" in Play Zone.
- **Cloud Function Proxy**: Dedicated CORS proxy wrapper for external API forwarding.

---

## [3.3.0] — 2026-06-13

### 🚀 Features
- **3 New HTML Games**: "Table Tennis World Tour", "Fun Race 3D" (Solo + 1v1 multiplayer obstacle courses), and "1v1 Match" matchmaking.
- **Lobby System**: Real-time room creation and matchmaking with room code sharing via Firestore.
- **Cinema Consolidation**: Deprecated separate `our_cinema` components and unified all watchlists under a consolidated Cinema screen and database schema.

---

## [3.2.0] — 2026-06-13

### 🚀 Features
- **Our Books Feature — Full Books Section**: Brand-new `BooksScreen` with four tabs (Home, Search, To Read, Read) mirroring the Cinema stack. Integrates Open Library API for book search, trending, subject discovery, and work details.
- **Open Library Integration**: `OpenLibraryService` talks to `openlibrary.org/search.json` (no API key required). Supports search, trending, subject-based discovery, work details, editions lookup, and Internet Archive text extraction.
- **In-App Reader**: `ReaderScreen` fetches plain text from Internet Archive or Open Library, parses chapters, and renders inline via `flutter_html`. Bookmark persistence and per-chapter navigation.
- **Our Books Shared List**: New `OurBooksScreen` / `OurBooksService` backed by Firestore `our_books` collection. Couple can maintain a shared book wish list with status tracking (To Read / Reading / Read) per partner.
- **Books Preview on Dashboard**: `BooksPreview` widget on the dashboard shows recently added or trending books.
- **Book Details Drawer**: Cinematic `BookDetailsDrawer` with cover art, metadata, subject chips, and read-source links. Mirrors the cinema `EpisodeDrawer` pattern.
- **Book Cover Cards**: `BookCoverCard` with press-scale animation, gradient overlays, and status badges.
- **OL Search Modal**: `OlSearchModal` — Open Library search dialog with debounced querying and add-to-list flow.
- **Chapter List**: `ChapterList` widget parses book text into chapter tiles for the reader.

### 🔧 Cinema Enhancements
- **Instant Carousel Trailers**: Removed the 2.5 s artificial delay for hero trailer playback. Trailers now play immediately on page change and are prefetched for every slide on mount so the first slide lands on a playing trailer, not a static backdrop.
- **Carousel Hold Duration Extended**: Auto-rotate timer now waits 18 s (up from 5 s) so the user has time to watch the trailer before the carousel advances. Timer resets on every manual swipe.
- **Carousel Trailer Prefetch**: `_prefetchCarouselTrailers()` warms TMDB trailer keys for every trending slide at mount time, ensuring instant playback on first load and every swipe.
- **Poster Hover Scale 1.5×**: Desktop poster hover scale increased from 1.15× to 1.5× with `Alignment.topCenter` so the hover preview fills more of the viewport. Animation eased to 220 ms `easeOutCubic`.
- **Stronger Cinematic Gradient**: Hero gradient stops tightened from `[0.0, 0.35, 0.70, 1.0]` to `[0.0, 0.28, 0.62, 1.0]` and poster tile gradient strengthened so title, year, and badges stay legible against any trailer frame.
- **ClipBehavior Fix**: `ListView` in the genre section now has `clipBehavior: Clip.none` wrapped in a `Stack` so the 1.5× poster scale doesn't clip on the edges.
- **Mobile Trailer Auto-Play**: Episode drawer now auto-plays the trailer on mobile as soon as the key is ready (desktop keeps the existing tap-to-play behavior). Trailer is muted on mobile to satisfy browser autoplay policies.
- **IgnorePointer on Gradients**: Cinematic gradient overlays in the episode drawer are wrapped in `IgnorePointer` so the Watch Trailer and Close Trailer buttons underneath remain tappable on mobile.

### 📝 Docs
- Updated CHANGELOG, README, and version for v3.2.0.
- New `RELEASE_NOTES_v3.2.0.md` documenting the full delta.

### ⚠️ Breaking Changes
- None. v3.2.0 is fully backward compatible with v3.1.0 data — all new Firestore writes are additive (`our_books` and `read_list` collections are new).

---

## [3.1.0] — 2026-06-13

### 🚀 Features
- **Live Presence Service**: New `PresenceService` + `PresenceStatus` model backed by Firestore `presence/{uid}` documents. Heartbeats every 15 s with `isOnline` / `lastSeen` / `isDoodling` / `lastDoodleAt` fields and 30 s online / 15 s doodle freshness windows. `setOffline`, `markDoodling`, `clearDoodling` are throttled and idempotent.
- **Partner Presence Indicator**: New `PartnerPresenceIndicator` widget renders a pulsing green dot in the Sanctuary chat header — "Clair is active" or "Active 5m ago" with second-level precision.
- **Partner Doodle Indicator**: New `PartnerDoodleIndicator` overlay on the Canvas screen shows a live "Clair is doodling ✨ 12s" banner with an animated pulsing dot whenever the partner is actively drawing.
- **Trailer Player**: New `TrailerPlayer` widget using a dedicated `HTMLIFrameElement` YouTube embed (`autoplay`, `muted`, `controls=0`, `loop=1`, `playlist={key}`, `enablejsapi=1`, `disablekb=1`, `playsinline=1`, `modestbranding=1`). Registered via `ui_web.platformViewRegistry` with a unique view-type per video key and pointer-events disabled so the iframe never blocks the parent gesture surface.
- **TMDB Trailer Fetching**: `TMDBService.fetchTrailerKey(tmdbId, mediaType)` hits `/{type}/{id}/videos` with a priority chain — official YouTube Trailer → any YouTube Trailer → any YouTube video. Results cached in a per-instance `_trailerCache` keyed by `mediaType_tmdbId`.
- **Cinema Carousel Live Trailers**: The trending hero carousel now swaps its still backdrop for the live, muted, looping YouTube trailer of the active card 2.5 s after the page settles. Cache-prefetches keys on page-change.
- **Cinema Poster Hover Trailers**: Desktop hover on a poster tile scales it to 1.15×, drops a rose-glow shadow, and 600 ms later swaps the poster for the looping trailer preview.
- **Our Cinema Hover Trailers**: Identical hover-to-play treatment on the shared list — scale 1.04, glassmorphic card lifts to `Color(0x2E2A1B3D)` with a deep-rose border, and a "TRAILER" green pill animates in while the trailer plays.
- **Episode Drawer Trailer**: A floating "Watch Trailer" button now sits on the cinematic hero backdrop. Tap to swap the 280 px hero for the full trailer player with a "Close Trailer" pill.
- **Videasy Autoplay & Next-Episode Params**: `VideoPlayerScreen` now appends `?autoplay=true` for movies and `?autoplay=true&nextButton=true&episodeSelector=true` for TV when the selected provider is Videasy.
- **Our Cinema Couple Badges**: New "Watched Together 💞" gradient pill (Khent → Clair) replaces the per-user chips when both partners have watched. Otherwise two compact avatar pills (K / C) light up in their respective accent color when watched.
- **Our Cinema Empty State CTA**: The empty "To Watch" tab now shows a glowing "Add a movie or series" pill that opens the TMDB search modal pre-scoped to "Ours".
- **Our Cinema Add Flow**: Header has a new `+` action button that opens `TMDBSearchModal` with `initialScope: 'ours'`, pre-selecting the couple chip.
- **TMDBSearchModal Initial Scope**: New `initialScope` parameter ('mine' or 'ours') with a guard that falls back to 'mine' for cinema-only users. Chip taps are now properly wired through `onTap` so the dialog re-renders the active chip.
- **Our Cinema Item → MediaItem Bridge**: `OurCinemaItem.toMediaItem()` adapter so the shared list can reuse the same `EpisodeDrawer` and watch flow as the personal Cinema screen.
- **Dashboard Heartbeat Lifecycle**: `_DashboardScreenState` is now a `WidgetsBindingObserver`. It starts a presence heartbeat on mount, restarts it on `AppLifecycleState.resumed`, and sets the user offline on `paused` / `hidden` / `detached`. Web `pagehide` and `beforeunload` listeners also flip the user offline.
- **Canvas Doodling Bumps**: `CanvasScreen` now calls `PresenceService.markDoodling(uid)` (1.5 s throttle) on every pan-start / pan-update and `clearDoodling` on dispose.

### 🐛 Bug Fixes
- **Guardian Particles Render**: Replaced `IgnorePointer(child: AnimatedPositioned(...))` with `AnimatedPositioned(key: ValueKey(angle), child: IgnorePointer(...))` so particle positions animate correctly when toggled.
- **Guardian Color API**: `Colors.pink[100]!.withOpacity(0.8)` → `Colors.pink[100]!.withValues(alpha: 0.8)` to match the deprecation sweep.
- **Episode Drawer Encoding**: Stripped a UTF-8 BOM that snuck into `episode_drawer.dart` and cleaned up the box-drawing header comment.
- **Episode Drawer 280 px Backdrop**: Backdrop image now has a proper `errorBuilder` fallback to `_cCard` instead of crashing on a 404.
- **Cinema Carousel Backdrop Fallback**: Hero background now uses an `errorBuilder` that falls back to `_cVelvet` so a missing backdrop on a trending item no longer flashes a broken-image icon.
- **Sanctuary Chat Header**: Replaced the static "v2.0.0-STABLE" label with a live `PartnerPresenceIndicator` so users can see when their partner is online in chat.

### ⚠️ Breaking Changes
- None. v3.1.0 is fully backward compatible with v3.0.0 data — `OurCinemaItem.toMediaItem()` is a new read-only bridge and all new Firestore writes are additive (`presence/{uid}` collection is new).

---

## [3.0.0] — 2026-06-12

### 🚀 Features
- **Cinematic Dark Luxury Cinema UI/UX**: Complete Cinema screen rebuild with floating pill nav bar, animated active-tab indicator, 320 px hero carousel with 4-stop cinematic gradient + shadow bloom, chapter-style section headers (accent bar + Cormorant Garamond title typography), shimmer skeleton loading, press-scale poster tiles, medal rank badges (gold / silver / bronze glow rings), rich watchlist grid with gradient overlays, glowing status badges per item, episode drawer rebuilt with 280 px cinematic hero backdrop, 5-star visual rating embedded in the backdrop, and per-genre distinct colored chips, gradient play button with rose-glow shadow, large-numeral episode tiles, colored cast avatar rings, and glass-feel review cards.
- **Piano Tiles — Full Engine Rewrite**: Brand-new renderer using `Ticker` + `ValueNotifier` + a single GPU-friendly `CustomPainter` (`PianoBoardPainter`) that paints all four lanes in one pass — zero per-frame widget rebuilds. Beat-locked scrolling, miss-tolerance grace window, tap-pulse ripples, O(1) tap resolution against the next pending note via per-lane `GestureDetector`s.
- **PianoAudioService Pool**: Pre-warms a pool of `AudioPlayer`s per MIDI note, pre-loads the nearest reference sample (`a.wav`, `c.wav`, `e.wav`, `f.wav`), and pitch-shifts via `setSpeed`. Taps fire-and-forget on the hot path with zero awaits for near-instant response. Lazy fallback that prepares an unprepared note on demand if the song touches a pitch outside the pre-warm pool.
- **Expanded Song Library**: *Twinkle Twinkle Little Star*, *Ode to Joy*, *Für Elise*, and *Canon in D (C-Major)* — with per-song tempo and difficulty (`Easy` / `Medium` / `Hard`).
- **Breyan (Cinema-Only) Access**: New passcode `9132` signs in as **Breyan**, a cinema-only sibling account. They land directly on the Cinema screen and have isolated watchlist data so the partner-only data stays private. Idempotent `migrateWatchListOwnership()` runs on every login to backfill `userName` on legacy watchlist documents.
- **Octagram Profile**: New passcode `8080` signs in as **Octagram**, another cinema-only sibling account, sharing the Breyan chip set.
- **Passcode Reshuffle**: Khent's gateway passcode is now `0938` (previously `2222`). Clair remains `0221`. Breyan is `9132`. Octagram is `8080`.
- **HexGL Drift Embed Boot Fixes**: Iframe no longer deadlocks on "Initializing 3D engine..." — hidden HexGL overlay in embed mode, auto-call `tryBootEmbed()` on iframe load, defer `hexGL.start()` behind `startEmbedRace()`. `postToParent('ready')` now fires as soon as the HexGL instance is created (so the Flutter overlay shows "Tap anywhere to start" right away) instead of waiting for every asset to download. New `progress` messages surface texture / geometry load progress. `web/hexgl/index.html` is now marked `no-cache` to bust the 1-hour Firebase Hosting CDN cache; a `v=3` cache-buster is appended to the Flutter iframe src. Uncaught errors and unhandled rejections inside the iframe are surfaced to the parent so future load failures show a real message instead of an infinite spinner.
- **Cinema Mobile Trending Scroll**: Trending list now scrolls on mobile and falls back to a velvet hero backdrop if the carousel image fails to load.
- **Cinema Back Stack Polish**: Skip the dashboard reveal animation for Breyan; hide the back button when the cinema navigation stack is empty.

### 🐛 Bug Fixes
- **Gateway Passcode Login on Empty Env**: `EnvConfig` now hardcodes TMDB, Last.fm, Clair, Khent, Breyan, and Octagram fallbacks so the gateway passcode flow no longer fails when Firebase env credentials are empty. `EnvConfig.missingRequired()` lists every missing credential for quick diagnostics.
- **Cinema Watch Screen Gestures**: Resolved the watch screen back-button click + mobile gesture overlap and defaulted the provider to Videasy.
- **Cinema Iframe Fix**: Real-iframe `postMessage` plumbing + Provider cleanup + a popup-ad sandbox.
- **HexGL Cache**: `web/hexgl/index.html` cache headers fixed; `v=3` cache-buster on the Flutter iframe src.

### 📝 Docs
- README rewritten to spotlight the v3.0.0 cinematic UI / Piano Tiles rewrite / Breyan access.
- `v2.1.0` / `v2.0.0` / `v1.5.x` release links preserved in the bottom of the file.

### ⚠️ Breaking Changes
- **Passcode change**: `2222` no longer signs in as Khent — use `0938`. `9132` and `8080` are new cinema-only entry points.

---

## [2.1.0] — 2026-05-18

### 🚀 Features
- **Play Zone Hub**: New "Play Zone" tile on the dashboard linking to Melody Tiles and HexGL Drift.
- **Melody Tiles Song Selection**: Track selector with difficulty, note count, high score, and best streak trackers per song.
- **HexGL Drift 1v1 Ghost Replay**: Firestore-backed `racingChallenges` collection with auto-respawn, professional touch UI, and asset-path fix (use `BASE_URL` for `/racing/`).
- **HexGL Drift Solo Time Trial**: Self-paced time trial mode with leaderboard persistence.

### 🐛 Bug Fixes
- Resolved build-context parentheses error in Play Zone launcher.
- Fixed music-sync relative import path after restructuring `lib/services`.

### 📝 Docs
- Updated v2.0.0 release details including the Melody Tiles rhythm game.

---

## [2.0.0] — 2026-04-22

### 🚀 Features
- **AssaultZone 1v1 Shooter**: Real-time two-player WebGL shooter with hit-reg and round-based scoring.
- **Melody Tiles (Piano Tiles)**: Native rhythm game tapping falling petals to produce piano melodies + XP awards.
- **Mobile Optimization**: Touch-target rewrites, viewport-aware layouts, and per-screen bottom-pad safe areas across Dashboard, Cinema, and Chat.
- **Bloat Cleanup**: Removed dead experiments, consolidated Firebase providers, and pruned the dependency tree.

### 🐛 Bug Fixes
- Resolved a build-context parentheses error in Play Zone.
- Fixed the music-sync relative import path.
- Fixed HexGL racing asset paths to use `BASE_URL` for the `/racing/` prefix.

### ⚠️ Breaking Changes
- Dashboard layout was re-templated; custom CSS overrides will need re-applying.

---

## [1.5.3] — 2026-03-30

### 🚀 Features
- **Real Iframe Fix**: `postMessage` plumbing for VidFast / VixSrc / Videasy / 2Embed embeds.
- **Multi-Provider Video**: Add VidFast, VixSrc, Videasy, 2Embed, and MultiEmbed to the cinema provider picker.
- **Provider Cleanup**: Trimmed dead ChangeNotifier wiring from the Cinema stack.
- **Popup-Ad Sandbox**: Iframes now run in a sandboxed context to keep popup ads off the parent window.

### 🐛 Bug Fixes
- Provider reorder no longer breaks the watch screen back button on mobile.
- Defaulted the cinema provider to Videasy for first-time users.

---

## [1.5.2] — 2026-03-21

### 🚀 Features
- **PH Streaming Rankings**: The Philippines trending tab now uses `watch_region=PH` so rankings look like the Netflix-PH top 10.

---

## [1.5.1] — 2026-03-12

### 🐛 Bug Fixes
- Hardened the iframe sandbox so `sandbox="allow-scripts allow-same-origin"` no longer lets providers escape the embed boundary.
- Polished cinema detail drawer typography.
- Polished dashboard tile hover states.

---

## [1.5.0] — 2026-03-02

### 🚀 Features
- **Trending Carousel**: Auto-playing `PageView` carousel for trending titles.
- **Genre Browsing**: Browse by Action, Comedy, Horror, Romance, etc., with genre-specific color chips.
- **Now Showing**: Movies currently in Philippine cinemas + newly released in a dedicated section.
- **Cast & Reviews**: Cast profiles and TMDB user reviews in the media details drawer.
- **Similar Titles**: "More Like This" recommendations in the episode drawer.

---

## [1.4.0] — 2026-02-18

### 🚀 Features
- **Cinema: Multi-Provider Video Player**: Provider switcher in the watch screen.
- **Episode Drawer**: Cinematic drawer with backdrop, rating, genre chips, and a "Play" CTA.
- **Watchlist Removal**: Swipe-to-remove + confirmation dialog for personal watchlist items.

---

## [1.3.0] — 2026-01-27

### 🚀 Features
- **Racing Game**: New "Midnight Drive" racing game in the Play Zone.
- **Auto-Respawn**: Vehicles respawn on crash with a 1.5 s invincibility window.
- **Professional Touch UI**: Steering assist, brake, and drift buttons sized for thumbs.

### 🐛 Bug Fixes
- Fixed racing asset paths to use `BASE_URL` for the `/racing/` prefix.

---

## [1.2.0] — 2025-12-22

### 🚀 Features
- **Play Zone Hub**: First version of the games hub tile on the dashboard.

---

## [1.1.0] — 2025-11-30

### 🚀 Features
- **Starlight Jar**: Drop gratitude notes and memories into a virtual jar with a glass-feel UI.
- **Canvas**: Collaborative drawing with real-time Firestore sync.
- **Academy**: Trivia game with 8 categories, solo study, and 1v1 challenges powered by OpenTDB.
- **Jukebox**: Live music status from Last.fm for both partners.
- **XP System**: Gamified levels, streaks, and sound effects awarded for daily check-ins and trivia wins.

---

## [1.0.0] — 2025-10-14 — Initial Release

### 🚀 Features
- **Gateway**: Animated passcode entry door (1111 = Clair, 2222 = Khent).
- **Dashboard**: Main hub with anniversary counter, XP, and all feature cards.
- **Heartbeat**: Daily mood tracking with partner status indicators.
- **Guardian**: Animated cat mascot with random messages and mood prompts.
- **Sanctuary**: Private real-time couple's chat.
- **Daily Bloom**: Virtual garden that grows with daily visits.
- **Date Randomizer**: 1000+ date ideas — shake to discover.
- **Cinema**: Shared movie / TV watch list powered by TMDB.
- **Flutter Web + Firebase Auth + Firestore + Storage + Hosting** baseline.

---

_Pre-1.0 development commits live in the git history; this changelog starts at the first public release._
