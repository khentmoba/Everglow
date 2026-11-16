# Flutter → React migration

Goal: every screen Clair can reach runs in React and looks and moves the
same as Flutter. The migration is **done** only when every box below is
ticked, the Flutter app can be switched off, and nothing changed for Clair.

A screen counts as done when:

1. `node tools/compare.mjs <path>` stays under ~1% different at phone and
   tablet size (what's left is text smoothing, not layout or color), and
2. its motion (taps, page changes, reveals) is checked with `tools/motion.mjs`
   or by matching Flutter's durations and curves line by line, and
3. it reads and writes the same Firestore data and calls the same cloud
   helpers as Flutter, with agent-mode demo data in place of couple data.

Order: the screens Clair uses most come first.

## Shell
- [x] Router guard (agent mode, `?jump`, sign-in redirect, cinema-only bounce)
- [x] Auth session, passcode check, offline remembered login
- [x] Agent HUD (floating dev toolbar)
- [x] Route memory (reopen where you left off)
- [ ] Update prompt + service worker / offline
- [ ] Push notifications sync
- [x] Error page (real one, not the placeholder)

## Screens (Flutter feature size in lines)
- [x] `/` Door + passcode — entry (2.4k)
- [ ] `/dashboard`, `/letterbox`, `/desktop-app` — dashboard (19.3k) — compare 1.8% / 2.3%, mostly edge smoothing; XP card top line differs
- [ ] `/cinema`, `/cinema/video/:id` — cinema (23.2k) — compare 1.3% / 2.7%
- [x] `/watch-party` — watch_party (11.6k)
- [ ] `/anime` — anime (21.5k) — home compare 0.74% / 1.18% (rest is poster image smoothing). Header, nav, hero + trailer, ticker, rows, cards ported 1:1. Still to check: watch page, episodes, Motchi sidebar, browse/schedule/search/my list/history/downloads pages
- [ ] `/manga`, `/manga/reader` — manga (17.6k) — compare 15% / 11.5%
- [ ] `/books` (+ reader, detail, listen, list, category, categories), `/our-books` — books (11.3k) — home compare 1.11% / 1.36% (rest is Skia vs browser text rasterising, half-pixel). Home, shelf widgets, cover cards, pill nav and catalog data (popular/recent) ported 1:1. Still to check: search results rows + filters, library grid, detail, reader, listen, list/category pages, our-books
- [ ] `/sanctuary` — chat (1.4k)
- [ ] `/gallery` — gallery (3.1k)
- [ ] `/journal` — journal (4.4k)
- [ ] `/tonight` — tonight (1.9k)
- [ ] `/calendar` — calendar (4.9k)
- [ ] `/garden` — daily_bloom (4.7k)
- [ ] `/starlight` — starlight_jar (2.1k)
- [ ] `/bucket-list` — bucket_list (4.6k)
- [ ] `/trips`, `/trips/:id` — trip_kit (2.2k)
- [ ] `/jukebox`, `/spotify/callback` — jukebox (12.3k)
- [ ] `/canvas` — canvas (1.5k)
- [ ] `/money` — money (1.3k)
- [ ] `/subs` — subs (1.3k)
- [ ] `/play-zone` (+ tt, tt/lobby, scribble, chess) — play_zone (4.7k)
- [ ] `/academy` (+ solo, match, podium) — academy (3.8k)
- [ ] `/motchi` (+ preferences, memory, trivia, today, minis), `/study` — ai (15.4k)
- [x] Shared pieces with no route of their own: xp, heartbeat, guardian, date_randomizer

## Switch-over (last)
- [ ] All CI checks run against the React build
- [ ] Hosting serves React; Flutter build retired
- [ ] Flutter code removed
