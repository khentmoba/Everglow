# Technical Research: Everglow Jukebox

## Decided: Last.fm API Integration
- **Decision**: Use `http` package for REST calls to Last.fm.
- **Rationale**: Standard Flutter approach for simple REST APIs. Last.fm doesn't require a complex SDK for `user.getRecentTracks`.
- **Alternatives considered**: `dio` (overkill for this single-endpoint use case).

## Decided: Real-Time Polling
- **Decision**: `Timer.periodic(Duration(seconds: 30), ...)` coupled with a `StreamController`.
- **Rationale**: As specified in requirements. Stream-based UI updates provide the cleanest separation of concerns and smooth transitions.
- **Alternatives considered**: Sockets (Last.fm doesn't support them for this).

## Decided: Vinyl Rotation & Marquee
- **Decision**: 
  - Vinyl: `RotationTransition` with an `AnimationController` (linear/repeat).
  - Marquee: Use `marquee` package or a custom `ListView` with an auto-scroll controller.
- **Rationale**: `marquee` package is robust and provides the exact "scrolling titles" effect requested.

## Decided: Heart Particle System
- **Decision**: Use `confetti` package with a custom `ConfettiController` and a heart-shaped `Path`.
- **Rationale**: Easy to trigger on specific artist matches and provides high-fidelity visual feedback.

## Decided: Spotify Deep-Linking
- **Decision**: Use `url_launcher` with `https://open.spotify.com/search/${Uri.encodeComponent("$artist $track")}`.
- **Rationale**: As clarified in the specification phase, this is the most reliable fallback.
