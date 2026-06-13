# v3.1.0 — Live Presence, Hover-to-Play Trailers & Our Cinema Glass UI

The **Live & Cinematic Update** brings real-time presence, full YouTube trailer integration across the Cinema stack, and a glassmorphic overhaul of the shared **Our Cinema** list.

Full release-by-release history is in [`CHANGELOG.md`](./CHANGELOG.md). This release only documents the **v3.1.0** delta.

## Live Presence Service

- **`PresenceService`** writes a 15 s heartbeat to Firestore `presence/{uid}` with `isOnline`, `lastSeen`, `isDoodling`, and `lastDoodleAt`. 30 s online / 15 s doodle freshness windows.
- **`PartnerPresenceIndicator`** renders a pulsing green dot in the Sanctuary chat header — "Clair is active" or "Active 5m ago" with second-level precision.
- **`PartnerDoodleIndicator`** overlay on the Canvas screen shows a live "Clair is doodling ✨ 12s" banner whenever the partner is actively drawing.
- **Dashboard heartbeat lifecycle** — `WidgetsBindingObserver` + browser `pagehide` / `beforeunload` listeners flip the user offline the moment they close the tab or background the app.

## Trailer Player + YouTube Integration

- **`TrailerPlayer`** uses a dedicated `HTMLIFrameElement` YouTube embed with `autoplay`, `muted`, `controls=0`, `loop=1`, `playlist={key}`, `enablejsapi=1`, `playsinline=1`, `modestbranding=1`, and `pointer-events: none` so the iframe never blocks the parent gesture surface.
- **`TMDBService.fetchTrailerKey(tmdbId, mediaType)`** hits `/{type}/{id}/videos` with a priority chain — official YouTube Trailer → any YouTube Trailer → any YouTube video — and caches the result per `mediaType_tmdbId`.
- **Cinema carousel trailers** — the trending hero swaps its still backdrop for the live, muted, looping YouTube trailer 2.5 s after the page settles.
- **Cinema poster hover trailers** — desktop hover scales the poster to 1.15×, drops a rose-glow shadow, and 600 ms later swaps the poster for the looping trailer preview.
- **Episode drawer trailer** — a floating "Watch Trailer" button on the cinematic hero backdrop opens a full trailer player with a "Close Trailer" pill.

## Our Cinema Glass UI + Couple Badges

- **Glassmorphic dark cards** (`Color(0x2E2A1B3D)`) with deep-rose border and 24 px shadow lift on hover.
- **"Watched Together 💞"** gradient pill (Khent → Clair) replaces the per-user chips when both partners have watched. Otherwise two compact avatar pills (K / C) light up in their respective accent color.
- **Hover-to-play trailers** on every list row with a green "TRAILER" pill that animates in while the trailer plays.
- **Add to Our Cinema flow** — `+` header button + empty-state CTA open `TMDBSearchModal` with `initialScope: 'ours'`, pre-selecting the couple chip.
- **`OurCinemaItem.toMediaItem()`** adapter lets the shared list reuse the same `EpisodeDrawer` and watch flow as the personal Cinema screen.

## Videasy Provider Polish

- `VideoPlayerScreen` now appends `?autoplay=true` for movies and `?autoplay=true&nextButton=true&episodeSelector=true` for TV when the selected provider is Videasy.

## Bug Fixes

- Guardian particles now animate their position correctly — `AnimatedPositioned` owns the key, `IgnorePointer` is the child.
- Guardian color uses `withValues(alpha:)` to silence the deprecation.
- Episode drawer backdrop has a proper `errorBuilder` fallback.
- Cinema carousel hero backdrop has a velvet fallback on image failure.
- Sanctuary chat header now shows the live partner indicator instead of a static version stamp.
- Stripped the UTF-8 BOM from `episode_drawer.dart` and tightened the `_trailerKey!` null assertion in the trailer stack.

## Breaking Changes

None. v3.1.0 is fully backward compatible with v3.0.0 data — `OurCinemaItem.toMediaItem()` is a new read-only bridge and all new Firestore writes are additive (`presence/{uid}` collection is new).

## Auto-Deployment

Push to `main` triggers the existing **Build and Deploy to Firebase** workflow (`.github/workflows/deploy.yml`). The workflow builds the Flutter web bundle, regenerates the auto-changelog, deploys to Firebase Hosting `live` channel, and updates this release artifact.

## Passcode Reference

| Passcode | Profile        | Access                              |
| -------- | -------------- | ----------------------------------- |
| `0221`   | Clair          | Full couple account                 |
| `0938`   | Khent          | Full couple account                 |
| `9132`   | Breyan         | Cinema-only sibling                 |
| `8080`   | Octagram       | Cinema-only sibling                 |
