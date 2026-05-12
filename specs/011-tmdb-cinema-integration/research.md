# Research: TMDB Cinema Integration

## TMDB API Integration

- **Decision**: Use the `/search/multi` endpoint for combined movie and TV show searching.
- **Rationale**: Simplifies the UI by providing a single search bar for all media types.
- **Alternatives Considered**: Searching `/search/movie` and `/search/tv` separately and merging results (more complex, higher API overhead).

## Poster URL Construction

- **Decision**: Use `https://image.tmdb.org/t/p/w500` as the base URL.
- **Rationale**: `w500` provides a good balance between image quality and load time for mobile/web grid views.
- **Alternatives Considered**: `original` (too slow), `w200` (potentially blurry on high-DPI screens).

## Debouncing Logic

- **Decision**: Implement a manual `Timer` in the Search Modal's state.
- **Rationale**: Avoids adding an extra package (like `easy_debounce`) for a simple task. 500ms delay is standard for live search.
- **Alternatives Considered**: `Stream` with `debounceTime` (requires `rxdart`), `EasyDebounce` package.

## Data Persistence

- **Decision**: Map TMDB results to a `MediaItem` model and store in a `watch_list` collection.
- **Rationale**: Keeps the Cinema feature decoupled from `Milestones` (relationship timeline) while maintaining a consistent Firestore structure.
- **Alternatives Considered**: Adding to `milestones` collection (mixes data types, complicates filtering).

## UI Aesthetic

- **Decision**: `GridView.builder` with `crossAxisCount: 2-3` and `ClipRRect` for high border radiuses.
- **Rationale**: Efficient for lists of images and aligns with the "pink, bouncy" Everglow theme.
- **Alternatives Considered**: `ListView` (less visual impact for posters).
