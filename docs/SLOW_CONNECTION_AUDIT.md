# Everglow on slow connections

Reviewed 2026-10-14. This is a source audit and implementation plan, not a
measured speed improvement. No app behavior, backend configuration, or live
couple data was changed or accessed.

The goal is to show useful content sooner, download fewer bytes, keep already
loaded content usable during failures, and distinguish local saves from server
confirmation. A first visit and a repeat visit need separate measurements.

## Implementation follow-up

The first pass below is now implemented on `t3/improve-slow-network-loading`:
thumbnail selection is shared across gallery previews; gallery/journal retain
stable query streams; the shared list retains mounted content during recognized
temporary failures and clears it for permission errors or a new source; the
viewer downloads full photos on demand; confirmed journal saves no longer wait
for XP. Journal uses its service's existing timeout rather than a second widget
timeout. Gallery Map/Week futures also stay stable across their rebuilds.

The viewer deliberately does no speculative neighbor prefetching, so it needs
no browser-specific connection detection. This trades some first-swipe waiting
on fast connections for predictable demand on slow connections.

The offline pending-write states, durable photo downloads, history/query changes,
and device timing targets in the second pass remain future work. Verification
and synthetic screenshots are recorded in `docs/pr-proof/slow-network/README.md`.

## What already helps

- Production Firestore settings enable persistence with a 100 MiB cache.
  Debug builds and builds served from localhost explicitly disable it in
  `lib/core/system/app_bootstrap.dart`. The installed, lockfile-matching
  `cloud_firestore_web` 4.4.12 implementation maps that setting to persistent
  local cache. Actual browser persistence still needs verification.
- Letterbox loads a disk cache and paints cached notes before live updates.
  Dashboard previews cap notes at 10, gallery metadata at 6, and journal at 12.
- Gallery uploads generate 400px thumbnails and max-1600px JPEG viewer images
  at quality 85. Main grids and dashboard previews select thumbnails when
  available. The viewer retains a thumbnail while the full image loads.
- Anime home rows and cinema watchlists have existing local caches. Lists
  generally build cards on demand; many dashboard sections are deferred.
- Startup code already uses deferred routes, and the service worker caches
  versioned app code and previously fetched chunks. Previously recorded bundle
  reductions in `docs/PERF_NOTES.md` are not a new measurement of this checkout.
- New journal title/content drafts survive a killed tab. Offline remembered
  login also already exists for previously authorized couple sessions.

## First pass: small changes with broad benefit

### 1. Keep live subscriptions stable and retain usable content

`lib/shared/widgets/everglow/everglow_stream_view.dart` constructs
`withFirestoreTimeout(...)` inside `build`. That creates a new stream identity
on every rebuild. Gallery and journal also construct their source streams in
their screen builds. Rebuilds therefore can cancel and replace subscriptions.
This establishes avoidable subscription churn, not a measured number of extra
server reads: Firestore can reuse cached documents and multiplex connections.

Hold the wrapped stream in widget state and replace it only when the source
changes. Hold screen queries in state and change them on explicit retry,
filter, or pagination actions. Keep existing rows visible during transient
refresh errors; permanent authorization errors must still remove access.
Avoid adding another timeout layer when a service already owns its retries.

Verification: count subscription/cancellation events through parent rebuilds;
check explicit retry and query changes; inject transient errors after data;
check permission denial and disposal.

### 2. Actually use thumbnails everywhere

`gallery_map_view.dart` has three small-image call sites using `imageUrl`.
`this_week_view.dart` also uses `imageUrl`. They pass `thumb: true`, but
`GalleryService.displayUrl` only adds a cache hint. The backend
`functions/media_proxy_gallery.js` explicitly does not resize the image.
Those widgets can download a full image for a small preview.

Use the stored `thumbUrl`, falling back to `imageUrl` for legacy records,
as the grid already does. Existing photos without thumbnails need a separate,
deliberate backfill if their transfer sizes prove costly; do not assume all
historical photos have the newer compressed variants.

Verification: synthetic records with/without thumbnails; inspect requested URLs
and bytes; compare phone/tablet sharpness. No live-data migration in this pass.

### 3. Give the current photo priority

`photo_viewer_screen.dart` precaches both neighboring full images after opening
and after page changes, without checking whether the current image has loaded
or the connection is constrained. This may compete with the selected image.

First let the selected image finish. Then warm at most the likely next image;
skip optional warming when offline or when a supported browser reports data
saving/slow connectivity. Provide conservative behavior where that signal is
unavailable. Avoid prefetching the whole album or every deferred feature.

Verification: record requests under shaping; current-photo load starts first;
neighbor failure does not affect viewing; rapid swipes remain correct.

### 4. Stop auxiliary work extending Save

`add_journal_entry_dialog.dart` awaits the entry write, then awaits
`XPService().awardJournal(uid)` before clearing drafts and closing. Award XP
in the background with logged errors after the entry is confirmed. This is a
small improvement even before changing offline write behavior.

Verification: delayed/failed XP must not delay or fail an otherwise successful
entry save; failed entry writes must retain the draft.

## Second pass: consistent behavior during weak or lost connectivity

### Local content and honest saving status

Use Firestore's existing persistent cache before adding a duplicate database.
Listeners can emit cached data and local changes. Preserve snapshot metadata
where the UI needs to distinguish cached/incomplete data from server results,
and pending writes from server confirmation. Empty cache results must not be
presented as proof that an album or journal has no entries.

Journal currently awaits Firestore writes, so a disconnected save can remain
pending rather than close promptly. Add explicit locally pending, synced, and
failed states. Use a stable document ID for retries of a new entry to prevent
duplicates. Do not clear the only recoverable draft until local durability is
established. This needs more care than simply removing `await`.

Private caches need session-aware access and cleanup behavior. Letterbox's
extra disk cache uses one global key; do not copy that pattern across every
feature without addressing profile changes, logout, and trusted devices.

### Photos and uploads

The web branch of `AppNetworkImage` uses `Image.network`; native uses
`CachedNetworkImage`. Web reuse relies on Flutter memory and browser HTTP
caching. The service worker ignores cross-origin resources, including the
gallery proxy, so it does not guarantee offline access to previously viewed
photos. Browser eviction also means a cache is not a permanent download.

First measure repeat-photo requests. If durable offline albums are wanted,
add an explicit bounded download feature with private-data cleanup, rather
than caching every photo automatically. Storage uploads currently await full
image, thumbnail, and metadata sequentially and expose no byte progress in
the dialog. Show real upload progress and retry status before designing a
persistent upload queue. Resizing also decodes the input twice synchronously;
measure phone responsiveness with a large synthetic camera photo before
choosing a worker/native background implementation.

### Search and larger collections

Gallery search reads every metadata page, then filters locally, for each
debounced search. Gallery Load More increases the live query from 40 to 80,
120, etc. Journal starts with up to 100 complete entries despite already
having pagination for older entries.

Reuse loaded metadata for immediate search results, then make additional
history searching explicit. Retain a bounded live gallery first page and
fetch older pages with cursors. Consider a smaller journal first page after
checking category filters, counts, search, and pagination boundaries.
Never silently make full-history searches incomplete to improve a timing.

Books combines Open Library, Gutenberg, and Internet Archive through
`Future.wait` in `book_catalog_service.dart`, so the merged result waits for
all sources to settle. A later pass can publish successful partial results
while slower sources finish, with stable ordering and clear completeness.
Cinema/anime/catalog caching should reuse their existing service caches.
External movie streams and third-party providers still have independent
bandwidth and availability limits.

## How to prove the result

Use synthetic private-feature fixtures and a stamped release build. Do not use
local debug speed or agent fixtures to claim authenticated Firestore speed.
Localhost also disables persistence, so offline database checks need an
isolated production-like host/build configuration and fake backend data.

Measure cold first visit, warm reopen, route revisit, and reconnect separately
at documented bandwidth/latency/loss settings. Record at least three runs per
case, transfer bytes, request counts, first usable content, selected-photo
time, and locally saved versus server-confirmed time. Observe a real phone
and tablet, including Safari/PWA where Clair uses them.

Cover dashboard, Letterbox, journal, gallery grid/map/week/viewer, cinema,
anime, manga reader, and books; then expand to the remaining private features.
For offline boot, disconnect both the page and service worker. Test fresh
uncached routes, existing cached routes, browser eviction, profile changes,
pending writes, reconnect, and a new deployment with an older cached shell.

Reuse `tool/perf/measure_boot.mjs`, `tool/perf/bench.mjs`, and the existing
service-worker browser checks where appropriate. Follow the required checks
in AGENTS.md when shipping implementation changes. Tool checks establish that
the harness works; they do not establish real-device speed.

Firebase references verified during this audit:

- [Offline persistence](https://firebase.google.com/docs/firestore/manage-data/enable-offline)
- [Realtime listeners, cache events, and pending writes](https://firebase.google.com/docs/firestore/query-data/listen)

The previous <2.5s throttled-3G first-interactive target remains unverified.
No whole-app percentage gain or guaranteed offline behavior is claimed here.
