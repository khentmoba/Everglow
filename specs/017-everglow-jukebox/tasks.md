# Tasks: Everglow Jukebox

## Phase 1: Setup

- [x] T001 Create feature directory structure in `lib/features/jukebox` (data, presentation, providers)
- [x] T002 Configure `.env` support and add Last.fm keys to root `.env` file
- [x] T003 [P] Add dependencies to `pubspec.yaml` (http, marquee, confetti, url_launcher, flutter_dotenv)

## Phase 2: Foundational

- [x] T004 Implement `MusicStatus` model in `lib/features/jukebox/data/models/music_status.dart`
- [x] T005 [P] Implement `MusicSyncService` with Last.fm polling logic in `lib/features/jukebox/data/services/music_sync_service.dart`
- [x] T006 Implement `JukeboxProvider` to manage state and streams in `lib/features/jukebox/presentation/providers/jukebox_provider.dart`

## Phase 3: [US1] Real-time Music Monitoring

**Goal**: Display live music status for Khent and Clair on the dashboard.
**Independent Test**: Mock Last.fm API responses and verify that the two cards update with track info and 'Live' status.

- [x] T007 [US1] Create basic `MusicCard` widget in `lib/features/jukebox/presentation/widgets/music_card.dart`
- [x] T008 [US1] Implement `JukeboxWidget` layout (side-by-side/stacked) in `lib/features/jukebox/presentation/widgets/jukebox_widget.dart`
- [x] T009 [US1] Integrate `JukeboxWidget` into the main dashboard scroll view
- [x] T010 [US1] Implement 'Live' pulsing indicator and inactive 'Last heard' state in `lib/features/jukebox/presentation/widgets/music_card.dart`

## Phase 4: [US2] Interactive Details & Spotify Integration

**Goal**: Allow users to click cards to see details and open Spotify.
**Independent Test**: Tap a card, verify the popup appears, and clicking the Spotify button opens the search URL.

- [x] T011 [US2] Create `ListenAlongPopup` dialog in `lib/features/jukebox/presentation/widgets/listen_along_popup.dart`
- [x] T012 [US2] Implement tap gesture on `MusicCard` to trigger the popup
- [x] T013 [US2] Implement Spotify search URL construction and `url_launcher` logic in the popup

## Phase 5: [US3] Aesthetics & Polish

**Goal**: Add premium animations and personalization for favorite artists.
**Independent Test**: Listen to Ethel Cain and verify heart particles; check that long titles scroll; check vinyl rotation.

- [x] T014 [US3] Create `VinylRecord` animated widget in `lib/features/jukebox/presentation/widgets/vinyl_record.dart`
- [x] T015 [US3] Integrate `VinylRecord` into `MusicCard` with rotation logic when `isPlaying` is true
- [x] T016 [US3] Implement `Marquee` text for long song titles in `lib/features/jukebox/presentation/widgets/music_card.dart`
- [x] T017 [US3] Implement `EthelCainHeartAnimation` using the `confetti` package in `lib/features/jukebox/presentation/widgets/music_card.dart`

## Phase 6: Final Polish

- [x] T018 Refine border radiuses ($32.0$) and soft pink shadows across all jukebox components
- [x] T019 Optimize mobile responsive layout (stacking cards)
- [x] T020 [P] Add unit tests for `MusicSyncService` data parsing

## Dependencies

- **US1** depends on **Phase 2** (Service/Model)
- **US2** depends on **US1** (UI Cards)
- **US3** depends on **US1** (UI Cards)

## Implementation Strategy

1. **MVP First**: Complete Phase 1-3 to get live data visible on the dashboard.
2. **Interactive Layer**: Add the Spotify popup (Phase 4).
3. **Premium Polish**: Add the animations and special triggers (Phase 5).
