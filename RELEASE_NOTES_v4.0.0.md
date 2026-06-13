# Everglow — Release Notes (v4.0.0)

Everglow has evolved significantly since the v3.2.0 release. This major version release (**v4.0.0**) consolidates all recent feature additions, security upgrades, game engine expansions, and user interface refinements.

---

## 🌟 Version 4.0.0 Highlights (2026-06-14)

### 🎮 Play Zone: Complete Game Booting & Gesture Polish
- **Gesture Area Expansion**: Modified booting/game-start overlays for **Table Tennis World Tour**, **Fun Race 3D**, and **HexGL Drift**. GDC wraps now listen to gestures across the entire screen instead of limited overlay targets, resolving interaction issues during boot.
- **Mobile Touch Refinements**: Tuned touch HUD overlays for mobile racing and tennis games for cleaner layout heights.

---

## 📖 Version 3.4.0 Highlights (2026-06-14)

### 📚 Manga Dex Integration & In-App Reader
- **Manga Library & Discovery**: Implemented a full-fledged `MangaLibraryScreen` and custom `MangaSearchModal` interacting with the **MangaDex API** for instant title queries and cover fetches.
- **Cinematic Detail Drawer**: Added `MangaDetailsDrawer` featuring high-quality covers, synopses, tag pills, and reading status tracking.
- **Custom Manga Reader**: Brand-new `MangaReaderScreen` built for rendering pages side-by-side or in vertical scroll with zoom controls and chapter navigation.
- **Manga Preview Widget**: Dashboard dashboard module showcasing trending or recently read manga.

### 🕹️ Masked Special Forces Game Embed
- **3D WebGL Shooter**: Integrated "Masked Special Forces" in the Play Zone. Contains a desktop-optimized 3D action environment.
- **Unity WebGL Loader plumbing**: Customized WebGL loaders (`UnityLoader.js` and `build_html.ps1`) to pre-load larger asset chunks without frame freezes.

### 🔌 Cloud Function Proxy
- **CORS Bypass Proxy**: Configured custom Cloud Functions to act as a secure proxy for third-party APIs (such as MangaDex) to avoid client-side cross-origin limitations on Web builds.

---

## 🕹️ Version 3.3.0 Highlights (2026-06-13)

### 🎳 Play Zone Expansion: 3 New HTML Games
- **Table Tennis World Tour**: Play through regional brackets using native touch or mouse-swipe gestures for aiming and paddle speed.
- **Fun Race 3D**: Integrated Gauntlet Runner with two modes:
  - **Solo**: Run through randomized physics obstacle courses.
  - **1v1 Lobby**: Create a room, share a match code, and compete in real-time.
- **1v1 Match Lobby**: Created a unified WebSocket/Firestore matchmaking system supporting real-time multiplayer states.

### 🎬 Cinema watchlist consolidation
- **Database Cleanup**: Deprecated separate screen components (`our_cinema_screen.dart`, `our_cinema_service.dart`, `our_cinema_item.dart`) and consolidated the couple's shared watch lists directly under the primary Cinema database pipeline, mapping media items with Firestore ownership attributes.

---

## 🛠️ Deploying & Upgrading

This release is fully configured for continuous integration. Pushing these changes to the `main` branch automatically triggers the GitHub Actions deploy pipeline:
1. Validating and building the Flutter Web bundle.
2. Building dependencies and injection configurations.
3. Hosting static content on Firebase CDN.
