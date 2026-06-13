# v3.2.0 — Our Books: Open Library Integration, In-App Reader & Cinema Polish

The **Books & Cinematic Polish Update** brings a full book discovery and reading experience powered by Open Library, plus instant carousel trailers and enhanced mobile playback.

## Our Books Feature

- **`BooksScreen`** — four-tab IndexedStack (Home, Search, To Read, Read) with a glassmorphic bottom nav, mirroring the Cinema pattern.
- **`OpenLibraryService`** — integrates `openlibrary.org/search.json` (no API key) for search, trending, subject discovery, work/edition details, and Internet Archive text extraction.
- **`ReaderScreen`** — fetches plain text from Internet Archive or Open Library, parses chapters, and renders inline via `flutter_html`. Bookmark persistence across sessions.
- **`OurBooksScreen` / `OurBooksService`** — Firestore-backed `our_books` collection for a shared couple book wish list with per-partner status (To Read / Reading / Read).
- **`BooksPreview`** — dashboard widget showing recently added books.
- **`BookDetailsDrawer`** — cinematic drawer with cover art, metadata, subject chips, and read-source links.
- **`OlSearchModal`** — Open Library search dialog with debounced querying.
- **`flutter_html`** dependency added for rich text rendering in the reader.

## Cinema Enhancements

- **Instant carousel trailers** — removed the 2.5 s artificial delay. Trailers play immediately on page change via `_startTrailerForPage(index)`.
- **Trailer prefetch** — `_prefetchCarouselTrailers()` warms TMDB keys for every trending slide at mount so the first slide lands on a playing trailer.
- **Extended hold duration** — auto-rotate waits 18 s (up from 5 s) and resets on every manual swipe.
- **Poster hover 1.5×** — desktop poster hover scale increased to 1.5× with `Alignment.topCenter` and 220 ms `easeOutCubic`.
- **Stronger gradients** — hero and poster gradients tightened so titles stay legible over any trailer frame.
- **Clip fix** — genre section `ListView` now has `clipBehavior: Clip.none` wrapped in a `Stack` to prevent 1.5× scale clipping.

## Episode Drawer Mobile Polish

- **Auto-play on mobile** — trailer plays automatically when the key is ready (desktop keeps tap-to-play). Muted on mobile to satisfy browser autoplay policies.
- **IgnorePointer on gradients** — gradient overlays wrapped so Watch Trailer / Close Trailer buttons stay tappable.

## Breaking Changes

None. v3.2.0 is fully backward compatible with v3.1.0 — `our_books` and `read_list` are new Firestore collections.

## Auto-Deployment

Push to `main` triggers the **Build and Deploy to Firebase** workflow (`.github/workflows/deploy.yml`). Builds Flutter web, deploys to Firebase Hosting `live` channel, and creates the release artifact.

## Passcode Reference

| Passcode | Profile        | Access                              |
| -------- | -------------- | ----------------------------------- |
| `0221`   | Clair          | Full couple account                 |
| `0938`   | Khent          | Full couple account                 |
| `9132`   | Breyan         | Cinema-only sibling                 |
| `8080`   | Octagram       | Cinema-only sibling                 |
