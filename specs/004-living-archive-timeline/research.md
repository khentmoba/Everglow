# Research: Living Archive Timeline

**Feature**: 004-living-archive-timeline  
**Date**: 2026-05-08  
**Status**: Complete — all NEEDS CLARIFICATION resolved

## Decision 1: Firestore Real-Time Listener Pattern

**Decision**: Single `.snapshots()` stream on the top-level `milestones` collection, ordered by `date` ascending. Exposed as a `Stream<List<Milestone>>` getter from `MilestoneService`.

**Rationale**: The existing `LetterboxService` uses the identical pattern (`.snapshots()` → `.map()`). Consistency reduces cognitive overhead. A single listener for a small collection (dozens of docs) has negligible cost vs. the complexity of pagination or manual re-fetching.

**Alternatives considered**:
- `.get()` one-time fetch — rejected; violates FR-002 (real-time requirement).
- Paginated `.limit(20)` query — rejected; clarified as out of scope in Q4.
- `StreamProvider` via `provider` package — considered; decided against to maintain consistency with the direct `StreamBuilder` pattern used in `LetterboxView`.

---

## Decision 2: Widget Architecture — Self-Contained vs. Injected Stream

**Decision**: `TimelineView` instantiates its own `MilestoneService` internally, matching the `LetterboxView` pattern exactly.

**Rationale**: `LetterboxView` creates its own `LetterboxService` instance and passes nothing through the constructor. Mirroring this pattern keeps the API surface minimal and the dashboard screen clean. Testability is preserved by the ability to mock `FirebaseFirestore.instance` in widget tests.

**Alternatives considered**:
- Injecting `Stream<List<Milestone>>` via constructor — more testable in isolation, but adds boilerplate to the dashboard and departs from established patterns.
- Using `Provider`/`Riverpod` — over-engineered for a private two-person app with one shared data stream.

---

## Decision 3: Alternating Card Layout Strategy

**Decision**: Use a `ListView.builder` inside a `SliverToBoxAdapter`, where each item is a `Row` with `MainAxisAlignment.start` or `.end` based on `index.isEven`. The central axis is a `Stack`-based approach: a thin vertical `Container` (gradient) centred in the screen, with heart icon nodes overlaid at each milestone row.

**Rationale**: A pure `Row`-per-item approach with a fixed-width central column (e.g., 48px for the axis + node) is simpler than `CustomPaint` and more maintainable. The axis becomes a `Column` of `[expanded line, heart icon, expanded line]` segments per row.

**Alternatives considered**:
- `CustomPaint` for the axis — more flexible for curved or animated lines, but overkill for a straight vertical gradient line.
- `timeline` pub.dev package — adds an external dependency for something easily built in ~50 lines of Flutter layout code; rejected for simplicity and design control.

---

## Decision 4: Image Loading & Error Handling

**Decision**: `Image.network(url, errorBuilder: (ctx, err, st) => const SizedBox.shrink())` inside a `ClipRRect`. When `imageUrl` is null, skip the image widget entirely. The card uses a conditional: `if (milestone.imageUrl != null) ...`.

**Rationale**: `errorBuilder` returning `SizedBox.shrink()` means a failed load leaves no broken image artefact — the card simply collapses to text-only, matching the spec requirement (FR-005). `ClipRRect` with `BorderRadius.vertical(top: Radius.circular(32))` maintains card shape.

**Alternatives considered**:
- `cached_network_image` package — good for caching, but adds a dependency. For a private couple's app with dozens of images, the Flutter SDK's built-in memory cache is sufficient.
- `FadeInImage` with a placeholder — adds visual noise; the spec doesn't require a loading shimmer for images.

---

## Decision 5: Date Formatting

**Decision**: `intl` package (`DateFormat('d MMMM yyyy').format(milestone.date)`) → `14 February 2024`.

**Rationale**: `intl` is already in `pubspec.yaml` (used elsewhere for localisation). No new dependency needed. The format `d MMMM yyyy` produces the agreed human-friendly long format from Q3.

**Alternatives considered**:
- Manual string formatting — brittle, locale-unaware.
- `DateFormat.yMMMMd()` — produces `February 14, 2024` (US-style). Rejected in favour of `d MMMM yyyy` which reads more naturally for the chosen locale.

---

## Decision 6: Empty & Error State Design

**Decision**:
- **Empty**: `Center(child: Column([Icon(Icons.favorite_border, size: 64, color: Colors.pink[200]), SizedBox(16), Text("No memories yet… add your first milestone 🌸")]))` — centred, warm, on-brand.
- **Error**: `Center(child: Text("Something went wrong loading your memories 💌", style: TextStyle(color: Colors.pink[300])))`.

**Rationale**: Both states maintain the pink aesthetic and avoid harsh error language. The empty state uses `Icons.favorite_border` (outline heart) to feel inviting rather than broken. These match the tone of the empty states already established in the Letterbox section.

**Alternatives considered**:
- Lottie animation for empty state — desirable in future, but out of scope and adds a dependency.
- Snackbar for errors — inappropriate; the timeline section is a persistent UI element, not an action-triggered context.
