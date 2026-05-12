# Service Contract: TMDBService

## Interface Definition

The `TMDBService` acts as the bridge between the external TMDB API and the internal Firestore database.

### Public Methods

#### `searchMedia(String query)`
- **Input**: `query` (String)
- **Output**: `Future<List<MediaItem>>`
- **Behavior**:
    - Debounces or is called after a debounce.
    - Hits `https://api.themoviedb.org/3/search/multi`.
    - Maps response JSON to `MediaItem` objects.
    - Prepends poster base URL.

#### `saveToWatchList(MediaItem item)`
- **Input**: `item` (MediaItem)
- **Output**: `Future<void>`
- **Behavior**:
    - Checks if `item.tmdbId` already exists in Firestore.
    - If exists, updates the `status` and `addedAt` fields.
    - If not, creates a new document in the `watch_list` collection.

#### `getWatchListStream()`
- **Input**: None
- **Output**: `Stream<List<MediaItem>>`
- **Behavior**:
    - Provides a real-time stream of items from the `watch_list` collection, ordered by `addedAt` descending.
