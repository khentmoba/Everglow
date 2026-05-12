# Quickstart: TMDB Cinema Integration

## Setup

1. Add `http: ^1.2.1` to `pubspec.yaml`.
2. Obtain a TMDB API Key from [themoviedb.org](https://www.themoviedb.org/settings/api).
3. Create `lib/core/constants/api_keys.dart` (git-ignored) and add:
   ```dart
   class ApiKeys {
     static const String tmdbApiKey = 'YOUR_API_KEY_HERE';
   }
   ```

## Key Components

- **TMDBService**: Handles API calls to TMDB and Firestore persistence.
- **TMDBSearchModal**: The UI for searching and adding movies.
- **CinemaScreen**: The main view for the shared watch list.

## Usage Example

```dart
final tmdbService = TMDBService();
// Search
List<MediaItem> results = await tmdbService.searchMedia('Interstellar');
// Add
await tmdbService.addToWatchList(results.first, 'to-watch');
```
