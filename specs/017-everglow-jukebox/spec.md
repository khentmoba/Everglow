# Feature Specification: Everglow Jukebox

**Feature Branch**: `017-everglow-jukebox`  
**Created**: 2026-05-11  
**Status**: Draft  
**Input**: User description: "Build a real-time music status feature called The Everglow Jukebox for my Flutter web app. This feature must display what both Khent and Clair Jassen are currently listening to on Spotify by using the Last.fm API. Directives for Implementation: 1. API Service Setup (MusicSyncService) Create a service to fetch data from the Last.fm user.getRecentTracks endpoint. Endpoint: [https://ws.audioscrobbler.com/2.0/?method=user.getrecenttracks&user=USER_NAME&api_key=YOUR_API_KEY&format=json&limit=1](https://ws.audioscrobbler.com/2.0/?method=user.getrecenttracks&user=USER_NAME&api_key=YOUR_API_KEY&format=json&limit=1) The service must handle two separate requests: one for Khent’s username and one for Clair’s. 2. The Dashboard Widget (JukeboxWidget) Integrate this into the main dashboard scroll view. The Layout: Create two elegant, side-by-side (or stacked on mobile) music cards. Left Card: 'Khent is vibing to...' Right Card: 'Clair is vibing to...' The Visuals: Display the album art as a rounded square with a soft glow effect. Include a scrolling 'marquee' effect for long song titles. If a user is currently listening, add a tiny, pulsing pink 'Live' indicator and a rotating vinyl record animation. If they aren't listening, dim the card slightly and show 'Last heard: [Song Name]'. 3. Real-Time Polling Logic Since this isn't a socket-based API, implement a Timer.periodic that fetches new data every 30 seconds while the app is in the foreground. Use a StreamController to push these updates to the UI so the transition between songs feels smooth. 4. Interactive 'Listen Along' Feature When one of the music cards is tapped, show a cute popup with the full song details and a 'Listen on Spotify' button that deep-links to that specific track. 5. Aesthetics & Polish Use high border radiuses ($32.0$ or higher) and soft pink shadows. If the song matches a specific 'favorite' artist (like Ethel Cain), trigger a special 'heart' particle animation over the card."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Real-time Music Monitoring (Priority: P1)

As Khent and Clair, we want to see what each other is listening to in real-time on our dashboard so we can feel connected through music.

**Why this priority**: This is the core functionality of the feature. Without the ability to see current music status, the feature provides no value.

**Independent Test**: Can be fully tested by mocking Last.fm API responses for two users and verifying that the dashboard cards update correctly every 30 seconds.

**Acceptance Scenarios**:

1. **Given** the app is on the dashboard, **When** Khent starts listening to a song on Spotify, **Then** Clair's dashboard should show Khent's song with a pulsing 'Live' indicator and rotating vinyl animation within 35 seconds.
2. **Given** a user is not listening to music, **When** the dashboard loads, **Then** the card should be dimmed and display "Last heard: [Song Name]".

---

### User Story 2 - Interactive Details & Spotify Integration (Priority: P2)

As a user, I want to click on a music card to see more details and easily listen to the same song on Spotify.

**Why this priority**: Enhances the "Jukebox" experience by allowing the partners to actually "listen along" or explore the music.

**Independent Test**: Tap a music card and verify that a popup appears with correct metadata and a functional Spotify deep-link.

**Acceptance Scenarios**:

1. **Given** a music card is visible, **When** I tap the card, **Then** a cute popup dialog should appear showing full artist, album, and track information.
2. **Given** the 'Listen Along' popup is open, **When** I tap the 'Listen on Spotify' button, **Then** the browser should attempt to open the Spotify track link.

---

### User Story 3 - Dynamic Aesthetics & Personalization (Priority: P3)

As a user, I want the interface to feel alive and celebrate my favorite artists with special effects.

**Why this priority**: Adds the "wow" factor and emotional resonance consistent with the Everglow brand aesthetic.

**Independent Test**: Mock a response with a "favorite" artist and verify the 'heart' particle animation triggers.

**Acceptance Scenarios**:

1. **Given** a user is listening to Ethel Cain, **When** the card updates, **Then** a special 'heart' particle animation should trigger over the card.
2. **Given** a long song title, **When** the card is displayed, **Then** the title should scroll in a marquee effect within the constrained card width.

---

### Edge Cases

- **API Failure**: How does the system handle a 404 or 500 error from Last.fm? (Assumption: Show "Status Unavailable" or last cached state).
- **Rate Limiting**: What happens if the API key exceeds its limit? (Assumption: Exponential backoff or user-friendly error message).
- **Network Loss**: How does the UI reflect a lost internet connection during polling? (Assumption: Stop polling and show a static "Offline" indicator).
- **Missing Album Art**: What is shown if Last.fm returns no image? (Assumption: Show a placeholder pink musical note icon).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST fetch recent tracks for two distinct Last.fm usernames.
- **FR-002**: System MUST poll the Last.fm API every 30 seconds while the app is in the foreground.
- **FR-003**: System MUST use a `StreamController` to push updates to the `JukeboxWidget`.
- **FR-004**: Cards MUST display album art with a rounded square shape ($32.0$ radius) and a soft glow.
- **FR-005**: Cards MUST show a pulsing pink 'Live' indicator and rotating vinyl animation when music is actively playing.
- **FR-006**: Cards MUST dim and show "Last heard: [Song Name]" when music is NOT actively playing.
- **FR-007**: System MUST provide a marquee scrolling effect for song titles that exceed card width.
- **FR-008**: System MUST display a 'Listen Along' popup with a Spotify deep-link upon tapping a card.
- **FR-009**: System MUST trigger a 'heart' particle animation for specific 'favorite' artists (e.g., Ethel Cain).

### Key Entities *(include if feature involves data)*

- **MusicStatus**: Represents the current or last heard track state for a user.
  - Attributes: `username`, `trackName`, `artistName`, `albumName`, `imageUrl`, `isPlaying`, `spotifyUrl`, `timestamp`.
- **JukeboxCard**: UI component representing a user's music status.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Dashboard music status updates occur within 5 seconds of the internal 30-second timer trigger.
- **SC-002**: Marquee animations maintain a consistent 60fps for a smooth visual experience.
- **SC-003**: Tapping the 'Listen on Spotify' button successfully opens the correct track URL 100% of the time when a valid ID is present.
- **SC-004**: The 'Live' pulsing animation and rotating vinyl correctly reflect the `nowplaying` attribute from the Last.fm response.

## Clarifications

### Session 2026-05-11
- Q: How should Spotify deep-links be derived if Last.fm doesn't provide them directly? → A: Option B: Construct a direct web link to a Spotify search for the artist and track title.
- Q: How should the Last.fm API key and usernames (Khent/Clair) be managed/stored? → A: Option A: Use environment variables or a `.env` file.
- Q: Which 'favorite' artist(s) should trigger the special heart animation? → A: "Ethel Cain" only.

## Assumptions

- Users will provide valid Last.fm usernames and a working API key via environment variables (`.env`).
- The "favorite" artist trigger is hardcoded for "Ethel Cain".
- Spotify deep-links are constructed as search URLs (`https://open.spotify.com/search/Artist%20Track`) to ensure reliability.
- Mobile layout will stack cards vertically while desktop shows them side-by-side.
