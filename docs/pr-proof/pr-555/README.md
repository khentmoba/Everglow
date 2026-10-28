# PR #555 Proof: Text Copying, Anime Middle-Click / New Tab, and Multi-Genre Selection

This PR delivers three key user experience improvements requested via community feedback:

1. **App-wide Text Selection & Copying**:
   - Wrapped the root view tree in `SelectionArea` so text (synopsis, titles, notes, chat messages) can be selected, highlighted, and copied across the app.
   - Preserves drawing smoothness in Canvas by wrapping the drawing gesture layer in `SelectionContainer.disabled`.

2. **Anime Middle-Click / Scrollwheel & Open in New Tab**:
   - Added `AnimeXNavigation` helper for building `/anime?id=...&malId=...&title=...` deep links.
   - `AnimeXPosterCard` and hover popovers now detect middle-clicks (scrollwheel clicks via `kTertiaryButton`) and Ctrl/Cmd+click to open anime directly in a new browser tab without losing browse position.
   - Added an explicit "Open in new tab" icon button in the desktop hover popover next to "Details →".
   - `GoRoute('/anime')`, `AnimeScreen`, and `AnimeXShell` accept initial query parameters (`id`, `malId`, `title`, `poster`, `ep`) and immediately launch into the watch page on load.

3. **Multi-Genre Selection**:
   - `AnimeXController.browseGenres` and `AnimeXBrowsePage` now support selecting multiple genres and themes simultaneously instead of just a single genre.
   - Expanded genre and theme options to include popular tags like "Isekai" and "Reincarnation".
   - Added interactive `_GenreMultiSelect` button and `_GenrePickerSheet` modal, along with active dismissible chips with 1-click removal.
   - `AniListService.fetchAnimexPage` queries AniList GraphQL with `$genre_in: [String]` and `$tag_in: [String]`, with fallback mapping to multiple Jikan MAL genre IDs.

## Proof Artifacts

- `anime-browse-phone.png`: Anime browse screen rendered at 430px mobile viewport in Agent Mode showing filter bar and grid.
- `anime-direct-deeplink-phone.png`: Direct navigation to `/anime?id=21&title=ONE%20PIECE` demonstrating instant detail/watch load.
- 9 new unit & widget tests in `test/features/anime/animex_improvements_test.dart` covering URI building, middle-click event detection, new-tab launching, multi-genre controller state, and picker sheet UI.
- All 1820 Flutter tests pass (`flutter test --exclude-tags="golden,network"`).
- All 15 CI guard checks pass (`dart tool/ci/check_*.dart`).
