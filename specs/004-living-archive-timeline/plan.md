# Implementation Plan: Living Archive Timeline

**Branch**: `004-living-archive-timeline` | **Date**: 2026-05-08 | **Spec**: [spec.md](./spec.md)  
**Input**: Feature specification from `specs/004-living-archive-timeline/spec.md`

## Summary

Build a vertically-scrolling, real-time relationship milestone timeline — the "Living Archive" — that integrates directly into the existing dashboard scroll area below the `LetterboxView`. Milestones are sourced from a top-level Firestore `milestones` collection and streamed in full without pagination. The UI follows the established pink-and-cute design system: alternating cards with `borderRadius: 32`, heart node markers, a soft pink gradient timeline axis, and conditional image rendering. Cards are non-interactive display items only.

## Technical Context

**Language/Version**: Dart 3 / Flutter 3.x (SDK ^3.11.3 per pubspec.yaml)  
**Primary Dependencies**: `cloud_firestore ^5.0.1`, `google_fonts ^6.2.1` (Quicksand), `animate_do ^3.3.4`, `intl ^0.19.0`  
**Storage**: Cloud Firestore — top-level `milestones/{id}` collection  
**Testing**: `flutter_test` (widget tests for `TimelineView`, unit tests for `Milestone.fromFirestore`)  
**Target Platform**: Flutter for Web (primary), mobile-compatible layout  
**Project Type**: Mobile / Web app — feature module within existing Flutter project  
**Performance Goals**: 60 fps scroll with full collection loaded (≤100 docs); real-time update latency ≤5s  
**Constraints**: No pagination; single persistent Firestore listener; image load failures fall back to text-only layout  
**Scale/Scope**: Single-couple private app; milestone count expected to stay in dozens, never thousands

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-checked after Phase 1 design.*

| Principle | Status | Evidence |
|-----------|--------|---------|
| I. Privacy-First Design | ✅ Pass | Milestones are in a private Firestore instance behind Firebase Auth. No public endpoints. No multi-tenant exposure. |
| II. High-Fidelity & Modern Aesthetics | ✅ Pass | Alternating cards, pink gradient timeline axis, heart icon nodes, `borderRadius: 32`, drop shadows, `intl`-formatted dates — premium feel by design. |
| III. Real-Time & Persistent Engagement | ✅ Pass | Single `.snapshots()` Firestore stream — timeline updates live without user action. |
| IV. Scalable Archival Structure | ✅ Pass | This IS the archive timeline the constitution explicitly mandates. Firestore ordering by Timestamp is natively scalable. |
| V. Evolving Core | ✅ Pass | `TimelineView` is a self-contained widget module; `MilestoneService` is a standalone service. Both can be extended independently. |

**Post-design re-check**: All gates still pass after Phase 1 design. No violations.

## Project Structure

### Documentation (this feature)

```text
specs/004-living-archive-timeline/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
└── tasks.md             # Phase 2 output (/speckit.tasks command)
```

### Source Code (repository root)

```text
lib/
└── features/
    └── dashboard/
        ├── domain/
        │   └── models/
        │       ├── hidden_note.dart          # [EXISTING]
        │       ├── anniversary_counter.dart  # [EXISTING]
        │       └── milestone.dart            # [NEW] Milestone data model
        │
        ├── data/
        │   └── services/
        │       ├── letterbox_service.dart    # [EXISTING]
        │       └── milestone_service.dart    # [NEW] Firestore stream service
        │
        └── presentation/
            ├── screens/
            │   └── dashboard_screen.dart     # [MODIFY] Add TimelineView below LetterboxView
            └── widgets/
                ├── letterbox_view.dart       # [EXISTING — no changes]
                ├── metric_card.dart          # [EXISTING — no changes]
                ├── note_card.dart            # [EXISTING — no changes]
                ├── note_dialog.dart          # [EXISTING — no changes]
                └── timeline_view.dart        # [NEW] Full timeline widget

test/
└── features/
    └── dashboard/
        ├── domain/
        │   └── models/
        │       └── milestone_test.dart       # [NEW] Unit tests for Milestone model
        └── presentation/
            └── widgets/
                └── timeline_view_test.dart   # [NEW] Widget tests for TimelineView
```

**Structure Decision**: Single Flutter project (Option 1). The Living Archive slots into the existing `features/dashboard` module following the identical `domain → data → presentation` layering already established for the Letterbox feature.

## Phase 0: Research

See [research.md](./research.md) for all resolved decisions.

## Phase 1: Design & Contracts

See [data-model.md](./data-model.md) for the `Milestone` entity definition and Firestore schema.

### Component Design Decisions

#### `milestone.dart` — Domain Model
- Mirrors the `HiddenNote` pattern exactly: named constructor, `fromFirestore` factory, `toFirestore` helper.
- `date` stored as Firestore `Timestamp`, converted to `DateTime` on read.
- `imageUrl` typed as `String?` — null means no image; never an empty string.

#### `milestone_service.dart` — Data Service
- Single class `MilestoneService` with one getter: `Stream<List<Milestone>> get milestones`.
- Uses `FirebaseFirestore.instance` directly (same pattern as `LetterboxService`).
- Orders by `date` ascending — oldest first.
- No caching logic; relies on Firestore SDK's default offline cache passively.

#### `timeline_view.dart` — Presentation Widget
- Stateless `TimelineView` widget that accepts a `Stream<List<Milestone>>` or creates its own `MilestoneService` instance internally (matching `LetterboxView`'s self-contained pattern).
- Uses `StreamBuilder<List<Milestone>>` for reactive rendering.
- **States**: loading skeleton → empty state → error state → populated timeline.
- **Layout**: `Stack` per milestone row: `CustomPaint` or `Container` for the central axis line + gradient; `Positioned` or `Row` for alternating left/right cards.
- **Central axis**: `LinearGradient` from `Colors.pink[200]` to `Colors.pinkAccent`, with `Icons.favorite` (filled, `Colors.pink[300]`) as the node at each milestone.
- **Card styling**: `Container` with `BoxDecoration`: `color: Colors.pink[50]`, `borderRadius: BorderRadius.circular(32)`, `boxShadow` with `Colors.pink[100]` at `blurRadius: 12, offset: Offset(0, 4)`.
- **Image**: `ClipRRect(borderRadius: BorderRadius.vertical(top: Radius.circular(32)))` wrapping `Image.network` with `errorBuilder` fallback to text-only layout.
- **Date formatting**: `intl` package — `DateFormat('d MMMM yyyy').format(milestone.date)` → `14 February 2024`.
- **Empty state**: `Column` with `Icons.favorite_border` (large, `Colors.pink[200]`) + text "No memories yet… add your first milestone 🌸".
- **Error state**: `Text` with `Colors.pink[300]` — "Something went wrong loading your memories 💌".

#### `dashboard_screen.dart` — Integration
- Add one new `SliverToBoxAdapter` immediately after the existing `LetterboxView` sliver (line 186), wrapping `TimelineView()` in the same `_maybeAnimate(FadeInUp)` pattern with a delay of `1200ms`.
- Add a `const SizedBox(height: 32)` spacer between `LetterboxView` and `TimelineView`.
- Import `timeline_view.dart`.
- No other changes to existing slivers.

### UI Wireframe (text representation)

```
┌─────────────────────────────────────────┐
│           [ LETTERBOX VIEW ]            │
└─────────────────────────────────────────┘
              ↕ 32px spacer
        ── Living Archive ──🤍──
        (section header with gradient rule)

┌──────────────┐    │    
│  ╔═══════╗  │    │    ← Left card (milestone 1)
│  ║ image ║  │    🤍   ← Heart node on axis
│  ╚═══════╝  │    │
│  Title       │    │
│  14 Feb 2024 │    │
│  Description │    │
└──────────────┘    │

          │    ┌──────────────┐
         🤍   │  ╔═══════╗  │  ← Right card (milestone 2)
          │    │  ║ image ║  │
          │    │  ╚═══════╝  │
          │    │  Title       │
          │    │  14 Mar 2024 │
          │    │  Description │
          │    └──────────────┘
```

## Complexity Tracking

No constitution violations. No complexity justification required.
