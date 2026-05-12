# Implementation Plan: Everglow Jukebox

**Branch**: `017-everglow-jukebox` | **Date**: 2026-05-11 | **Spec**: [spec.md](file:///c:/APPLICATIONS\Everglow\specs\017-everglow-jukebox\spec.md)
**Input**: Feature specification from `/specs/017-everglow-jukebox/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/plan-template.md` for the execution workflow.

## Summary

The Everglow Jukebox is a real-time music status feature that displays what Khent and Clair are listening to on Spotify via the Last.fm API. The technical approach involves a polling service (`MusicSyncService`) using `Timer.periodic` and `StreamController` to push updates every 30 seconds. The UI (`JukeboxWidget`) features premium animations including a rotating vinyl record, pulsing 'Live' indicators, marquee song titles, and heart particle effects for "Ethel Cain".

## Technical Context

**Language/Version**: Dart 3.x (Flutter 3.x)
**Primary Dependencies**: `http`, `marquee`, `confetti`, `url_launcher`, `flutter_dotenv`
**Storage**: N/A (Real-time polling)
**Testing**: Flutter Widget Tests, Unit Tests for `MusicSyncService`
**Target Platform**: Flutter Web
**Project Type**: Web Application Feature
**Performance Goals**: 60fps animations, <5s latency from poll completion to UI update
**Constraints**: Last.fm API rate limits (mitigated by 30s polling)
**Scale/Scope**: 2 users, single dashboard widget

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **Privacy-First**: ✅ Feature is internal to the gated dashboard. Last.fm data is public but displayed only to authenticated partners.
- **High-Fidelity**: ✅ Includes premium animations (rotating vinyl, heart particles, marquee) and soft glow aesthetics.
- **Real-Time**: ✅ Implements 30s polling for persistent engagement.
- **Scalable**: ✅ Service-based architecture allows for easy extension or replacement of data sources.

## Project Structure

### Documentation (this feature)

```text
specs/017-everglow-jukebox/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
└── tasks.md             # Phase 2 output (to be generated)
```

### Source Code (repository root)

```text
lib/
├── features/
│   └── jukebox/
│       ├── data/
│       │   ├── models/
│       │   │   └── music_status.dart
│       │   └── services/
│       │       └── music_sync_service.dart
│       ├── presentation/
│       │   ├── widgets/
│       │   │   ├── jukebox_widget.dart
│       │   │   ├── music_card.dart
│       │   │   └── vinyl_record.dart
│       │   └── providers/
│       │       └── jukebox_provider.dart (or Controller)
```

**Structure Decision**: A feature-first structure under `lib/features/jukebox` will be used to maintain modularity and ease of integration into the main dashboard.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| None | N/A | N/A |
