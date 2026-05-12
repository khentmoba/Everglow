# Feature Specification: TMDB Cinema Integration

**Feature Branch**: `011-tmdb-cinema-integration`  
**Created**: 2026-05-11  
**Status**: Draft  
**Input**: User description: "Upgrade the Everglow Cinema feature in my Flutter web app to integrate the TMDB (The Movie Database) API for searching and adding media, rather than manual data entry. Directives for Implementation: 1. API Setup & Service (TMDBService) Create a TMDBService class to handle HTTP requests. Implement a searchMedia(String query) function that hits the TMDB Search API (/search/multi is preferred to get both TV shows and movies). Parse the JSON response to extract the title (or name for TV), media_type, and the poster_path. Construct the full image URL by prepending https://image.tmdb.org/t/p/w500 to the poster_path. 2. The UI: Search Bottom Sheet / Dialog Update the 'Add Movie/Series' button in the Creator Mode (or add a floating '+' button in the Cinema screen) to open a new TMDB Search Modal. The Layout: Include a soft, rounded TextField at the top for the search query. Below it, display the live search results using a GridView or a horizontal scrolling list. The Aesthetic: The search results should look like mini movie posters with high border radiuses. Keep the soft pink, bouncy 'Everglow' theme. 3. The 'Add to Everglow' Logic When a search result is tapped, prompt the user with a cute dialog: 'Add [Title] to Everglow?'. Include a toggle to select the starting status: 'To Watch' or 'Watched'. Firebase Integration: On confirm, map the TMDB data to our existing MediaItem model and push it to the watch_list collection in Cloud Firestore. Ensure the TMDBService allows me to easily inject my API Key as a constant or environment variable."

## Clarifications

### Session 2026-05-11
- Q: Search Results Layout → A: Option A (GridView with 2-3 columns).
- Q: Duplicate Media Handling → A: Option A (Update Existing status if already present).
- Q: API Key Injection Strategy → A: Option A (Static Constant in a configuration file).
- Q: Default Media Status → A: Option A ('To Watch' is selected by default).
- Q: TV Show Detail Level → A: Option A (Track entire series as a single entity).

### User Story 1 - Search & Find Media (Priority: P1)

As Khent (Creator), I want to search for movies and TV shows by title so that I don't have to manually enter movie details like titles and posters.

**Why this priority**: Core efficiency improvement and the main goal of the integration.

**Independent Test**: Open the search modal, type a movie title, and verify that relevant results appear with posters and correct titles.

**Acceptance Scenarios**:

1. **Given** the search modal is open, **When** I type "Inception" in the search field, **Then** I should see a list/grid of results including the movie "Inception" with its poster.
2. **Given** I am searching, **When** I type a TV show name like "The Bear", **Then** I should see results for both TV shows and movies.

---

### User Story 2 - Add Media to Everglow (Priority: P1)

As Khent, I want to tap a search result and add it to our shared watch list so that we can keep track of what we want to watch or have already watched.

**Why this priority**: Essential for data persistence and the primary action of the feature.

**Independent Test**: Tap a result, select a status (To Watch/Watched), confirm the dialog, and verify it is saved to the Firestore collection.

**Acceptance Scenarios**:

1. **Given** I tap a search result, **When** the confirmation dialog appears, **Then** I should see the movie title and a toggle for "To Watch" or "Watched".
2. **Given** I confirm adding a movie, **When** I check Firestore, **Then** a new document should exist in the `watch_list` collection with the correct TMDB data and selected status.

---

### User Story 3 - View Cinema Collection (Priority: P2)

As a user (Clair or Khent), I want to see our collection of movies and shows in a dedicated "Cinema" screen so that we can browse our shared media.

**Why this priority**: Provides visibility and value for the data being collected.

**Independent Test**: Navigate to the Cinema screen and verify that added items are displayed.

**Acceptance Scenarios**:

1. **Given** items have been added to the watch list, **When** I view the Cinema screen, **Then** I should see the movie posters in a cute, themed layout.

---

### Edge Cases

- **No Search Results**: How does the system handle a query that returns no results from TMDB? (System SHOULD display a cute "No movies found! 🌸" message).
- **Missing Poster**: What happens if a TMDB result has no `poster_path`? (System SHOULD show a pink placeholder image).
- **Network Error**: How does the system handle API failures or timeout? (System SHOULD show a retry button or a user-friendly error message).
- **Duplicate Addition**: If an item with the same TMDB ID already exists in the `watch_list`, the system MUST notify the user and allow them to update the status (e.g., from 'To Watch' to 'Watched') instead of creating a duplicate entry.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST implement a `TMDBService` that handles authentication and HTTP requests to the TMDB API.
- **FR-002**: System MUST use the `/search/multi` endpoint to allow searching for both Movies and TV shows.
- **FR-003**: System MUST parse TMDB responses into a `MediaItem` model (or equivalent).
- **FR-004**: System MUST construct full poster URLs using the `https://image.tmdb.org/t/p/w500` prefix.
- **FR-005**: System MUST provide a Search Modal with a rounded `TextField` and a GridView (2-3 columns) displaying the live search results.
- **FR-006**: Search results MUST display posters with high border radiuses (e.g., 16-24px).
- **FR-007**: System MUST prompt for confirmation before adding an item, including a status toggle defaulting to 'To Watch'.
- **FR-008**: System MUST persist added items to the `watch_list` collection in Firestore.
- **FR-009**: System MUST support injecting the TMDB API Key as a static constant in a dedicated configuration file.
- **FR-010**: System MUST include a "Cinema" screen/view to display the saved watch list.

### Key Entities *(include if feature involves data)*

- **MediaItem**:
    - `id`: String (Firestore ID)
    - `tmdbId`: int (The ID from TMDB)
    - `title`: String (Movie title or TV show name)
    - `mediaType`: String ('movie' or 'tv')
    - `posterPath`: String (Full URL to the poster)
    - `status`: String ('to-watch' or 'watched')
    - `addedAt`: DateTime (When it was added)

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Search results appear within 1.5 seconds of typing (debounce required).
- **SC-002**: 100% of added items are correctly synced to Firestore with all required fields.
- **SC-003**: UI matches the "Everglow" aesthetic (pink tones, rounded corners, bouncy animations).
- **SC-004**: Users can add a movie in under 3 taps (Search -> Tap Result -> Confirm).

## Assumptions

- **TMDB API Key**: Assumes the user will provide a valid TMDB API Key.
- **Existing Models**: Assumes `MediaItem` is either already defined or needs to be defined as specified.
- **Firestore Access**: Assumes the application has write access to the `watch_list` collection.
- **TV Show Tracking**: Assumes TV shows are tracked at the series level only (no season/episode tracking).
