# Tasks: Living Archive Timeline

**Input**: Design documents from `specs/004-living-archive-timeline/`  
**Branch**: `004-living-archive-timeline`  
**Prerequisites**: plan.md ✅ · spec.md ✅ · research.md ✅ · data-model.md ✅

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story. Tests are included for the domain model only (unit-testable without Firebase); UI widget tests are noted as optional.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies on each other)
- **[Story]**: Which user story this task belongs to (US1, US2, US3)
- Exact file paths are included in every task description

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Confirm the existing project scaffolding is ready to accept the new feature module. No new packages are required — all dependencies (`cloud_firestore`, `intl`, `animate_do`, `google_fonts`) are already in `pubspec.yaml`.

- [x] T001 Verify `pubspec.yaml` already contains `cloud_firestore`, `intl`, `animate_do`, `google_fonts` — no additions needed (`pubspec.yaml`)
- [x] T002 Create the directory `lib/features/dashboard/domain/models/` if it does not already exist (it does — `hidden_note.dart` lives there; confirm path is correct)
- [x] T003 Create the directory `test/features/dashboard/domain/models/` for unit tests (`test/features/dashboard/domain/models/`)

**Checkpoint**: Project structure confirmed — no new dependencies or directories to scaffold.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core domain model and service that ALL three user stories depend on. Nothing else can be built until these are complete.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete.

- [x] T004 Create `Milestone` domain model with `id`, `title`, `description`, `date` (DateTime), `imageUrl` (String?) fields, `fromFirestore` factory (mapping Firestore Timestamp → DateTime), and `toFirestore` helper — file: `lib/features/dashboard/domain/models/milestone.dart`
- [x] T005 [P] Create `MilestoneService` with a single `Stream<List<Milestone>> get milestones` getter that opens a persistent `.snapshots()` listener on the `milestones` collection ordered by `date` ascending — file: `lib/features/dashboard/data/services/milestone_service.dart`
- [x] T006 [P] Write unit tests for `Milestone.fromFirestore`: verify all fields map correctly (including null `imageUrl`), verify Timestamp converts to DateTime, verify missing required field throws — file: `test/features/dashboard/domain/models/milestone_test.dart`

**Checkpoint**: `Milestone` model and `MilestoneService` compile cleanly. Unit tests for the model pass. Foundation ready for all user story UI work.

---

## Phase 3: User Story 1 — View Chronological Milestone History (Priority: P1) 🎯 MVP

**Goal**: Render a fully styled vertical timeline in the dashboard scroll area, with alternating left/right milestone cards, a pink gradient central axis with heart node markers, and correct `DD Month YYYY` date formatting. Works with seeded Firestore data.

**Independent Test**: Seed Firestore with 3 milestones (2 with `imageUrl`, 1 without). Open the dashboard. Verify: (a) all 3 cards appear below the Letterbox in oldest-to-newest order; (b) card 1 is left-aligned, card 2 right-aligned, card 3 left-aligned; (c) images appear with rounded top corners on cards 1 & 2; (d) card 3 shows text-only with no broken image artefact; (e) dates render as e.g. `14 February 2024`.

### Implementation for User Story 1

- [x] T007 [US1] Create `TimelineView` StatelessWidget skeleton with a `StreamBuilder<List<Milestone>>` that instantiates `MilestoneService` internally — file: `lib/features/dashboard/presentation/widgets/timeline_view.dart`
- [x] T008 [US1] Implement the loading state in `TimelineView`: show a centred `CircularProgressIndicator` with `color: Colors.pink[300]` while the stream has no data — file: `lib/features/dashboard/presentation/widgets/timeline_view.dart`
- [x] T009 [US1] Implement the populated timeline layout in `TimelineView`: use a `ListView.builder` where each row is a `Row` containing a left card slot (expanded), a central axis column (fixed 48px width), and a right card slot (expanded); odd-index milestones fill the left slot (right slot is `Expanded(child: SizedBox())`), even-index milestones fill the right slot — file: `lib/features/dashboard/presentation/widgets/timeline_view.dart`
- [x] T010 [US1] Implement the central axis column for each timeline row: a thin `Container` (width 2, gradient `Colors.pink[200]` → `Colors.pinkAccent`) as the vertical line, with `Icon(Icons.favorite, color: Colors.pink[300], size: 20)` centred as the node marker — file: `lib/features/dashboard/presentation/widgets/timeline_view.dart`
- [x] T011 [US1] Implement the milestone card widget (private `_MilestoneCard` or inline builder) with: `BoxDecoration` using `color: Colors.pink[50]`, `borderRadius: BorderRadius.circular(32)`, `boxShadow: [BoxShadow(color: Colors.pink[100]!, blurRadius: 12, offset: Offset(0, 4))]` — file: `lib/features/dashboard/presentation/widgets/timeline_view.dart`
- [x] T012 [US1] Add conditional image rendering to `_MilestoneCard`: if `milestone.imageUrl != null`, render `ClipRRect(borderRadius: BorderRadius.vertical(top: Radius.circular(32)), child: Image.network(url, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox.shrink()))` at the top of the card — file: `lib/features/dashboard/presentation/widgets/timeline_view.dart`
- [x] T013 [US1] Add text content to `_MilestoneCard`: title in bold Quicksand `Colors.pink[900]`, date formatted via `DateFormat('d MMMM yyyy').format(milestone.date)` in smaller `Colors.pink[400]` weight, description in `Colors.pink[800]` with soft wrapping — import `package:intl/intl.dart` — file: `lib/features/dashboard/presentation/widgets/timeline_view.dart`
- [x] T014 [US1] Add a section header above the `ListView.builder`: a `Row` with two `Expanded` `Divider` widgets (color `Colors.pink[200]`) flanking the text `"Living Archive 🤍"` in Quicksand bold `Colors.pink[400]` — file: `lib/features/dashboard/presentation/widgets/timeline_view.dart`
- [x] T015 [US1] Integrate `TimelineView` into `DashboardScreen`: add `import '../widgets/timeline_view.dart'`, insert a `const SizedBox(height: 32)` sliver spacer after the existing `LetterboxView` sliver, then add a new `SliverToBoxAdapter` wrapping `_maybeAnimate(animation: FadeInUp(delay: 1200ms), child: const TimelineView())` — file: `lib/features/dashboard/presentation/screens/dashboard_screen.dart`
- [x] T016 [US1] Seed Firestore `milestones` collection with 3 sample documents (2 with imageUrl, 1 without) using the seed data defined in `data-model.md` and manually verify the full timeline renders correctly end-to-end in the running app

**Checkpoint**: User Story 1 is fully functional. The dashboard shows a styled timeline with alternating cards, heart nodes, gradient axis, images, and `DD Month YYYY` dates. Independently verifiable without US2 or US3.

---

## Phase 4: User Story 2 — Real-Time Archive Updates (Priority: P2)

**Goal**: The running dashboard timeline automatically reflects a new or updated milestone document added to Firestore without any user interaction or page reload.

**Independent Test**: With the dashboard open, add a new document to the `milestones` Firestore collection (via Firebase Console or a dev script). Verify the new card appears at the correct chronological position within 5 seconds. Then update the `title` of an existing document and verify the card text updates automatically.

### Implementation for User Story 2

- [x] T017 [US2] Verify the existing `StreamBuilder<List<Milestone>>` in `TimelineView` (from T007) correctly propagates Firestore `QuerySnapshot` changes — no code change expected; this is a validation task confirming the `.snapshots()` stream from `MilestoneService` (T005) handles real-time adds and updates — file: `lib/features/dashboard/presentation/widgets/timeline_view.dart`
- [x] T018 [US2] Verify the `ListView.builder` re-renders with the new list whenever the stream emits — confirm no `key` or `const` usage on the builder that would prevent rebuild — file: `lib/features/dashboard/presentation/widgets/timeline_view.dart`
- [x] T019 [US2] Add a `MilestoneService.addMilestone(Milestone m)` helper method that writes a new document to `milestones` (for use in dev seeding and future admin UI) — file: `lib/features/dashboard/data/services/milestone_service.dart`
- [x] T020 [US2] Perform end-to-end live validation: with the Flutter app running (`flutter run`), add a document directly in the Firebase Console and confirm live update appears in the timeline within 5 seconds

**Checkpoint**: Real-time sync confirmed working. US1 timeline + US2 live updates both independently verified.

---

## Phase 5: User Story 3 — Empty State Experience (Priority: P3)

**Goal**: When the `milestones` Firestore collection contains zero documents, the timeline section renders a warm, on-brand empty state prompt instead of a blank area. When Firestore throws an error, a friendly error message is shown without crashing the dashboard.

**Independent Test**: Clear all documents from the `milestones` collection (or test with a Firestore collection that doesn't exist yet). Open the dashboard — the timeline area must show the empty state prompt. Disconnect network and re-open — the error state must appear without a crash.

### Implementation for User Story 3

- [x] T021 [US3] Implement the empty state in `TimelineView`'s `StreamBuilder`: when `snapshot.hasData && snapshot.data!.isEmpty`, render `Center(child: Column([Icon(Icons.favorite_border, size: 64, color: Colors.pink[200]), SizedBox(16), Text("No memories yet… add your first milestone 🌸", textAlign: TextAlign.center, style: ...)]))` — file: `lib/features/dashboard/presentation/widgets/timeline_view.dart`
- [x] T022 [US3] Implement the error state in `TimelineView`'s `StreamBuilder`: when `snapshot.hasError`, render `Center(child: Padding(padding: EdgeInsets.all(24), child: Text("Something went wrong loading your memories 💌", textAlign: TextAlign.center, style: TextStyle(color: Colors.pink[300], fontSize: 16))))` — file: `lib/features/dashboard/presentation/widgets/timeline_view.dart`
- [x] T023 [US3] Verify empty state renders: temporarily comment out `seedInitialNotes` (or use a fresh Firestore project) and confirm the empty-state `Column` appears in the correct dashboard position below the Letterbox — file: `lib/features/dashboard/presentation/widgets/timeline_view.dart`

**Checkpoint**: All three user stories are independently functional. Timeline displays correctly for populated, empty, and error states.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Final visual refinements, edge case hardening, and code hygiene across all components.

- [x] T024 [P] Add `const` constructors to `Milestone` and `_MilestoneCard` where applicable to reduce rebuild cost — files: `lib/features/dashboard/domain/models/milestone.dart`, `lib/features/dashboard/presentation/widgets/timeline_view.dart`
- [x] T025 [P] Validate long-description edge case: insert a milestone with a 500-character description and confirm the card expands without overflowing or clipping the timeline layout — `lib/features/dashboard/presentation/widgets/timeline_view.dart`
- [x] T026 [P] Validate broken image URL edge case: insert a milestone with `imageUrl: "https://invalid.url/broken.jpg"` and confirm the card falls back to text-only with no broken image icon or layout shift — `lib/features/dashboard/presentation/widgets/timeline_view.dart`
- [x] T027 Add `SizedBox(height: 100)` bottom padding after the `TimelineView` sliver to ensure the last card is never obscured by the FAB — `lib/features/dashboard/presentation/screens/dashboard_screen.dart`
- [x] T028 [P] Code review: confirm `MilestoneService` does not hold a reference that prevents garbage collection (no stored `StreamSubscription`; the `StreamBuilder` manages the subscription lifecycle) — `lib/features/dashboard/data/services/milestone_service.dart`
- [x] T029 [P] Update `specify-rules.md` agent context if any new patterns were introduced during implementation (e.g., `DateFormat` usage, `BoxDecoration` shadow tokens)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — verify immediately
- **Foundational (Phase 2)**: Depends on Phase 1 — BLOCKS all user stories
- **US1 (Phase 3)**: Depends on Phase 2 (T004, T005) — primary deliverable / MVP
- **US2 (Phase 4)**: Depends on Phase 2 (T005) — validation-heavy; can run concurrently with US1 after T005 is done
- **US3 (Phase 5)**: Depends on Phase 3 (T007, T008) — the `StreamBuilder` shell from US1 is required
- **Polish (Phase 6)**: Depends on all user stories being complete

### User Story Dependencies

| Story | Depends On | Can Parallel With |
|-------|-----------|-------------------|
| US1 (P1) | T004, T005 (Foundational) | US2 after T005 |
| US2 (P2) | T005 (Foundational), T007 (US1 StreamBuilder) | US1 tasks T009–T016 |
| US3 (P3) | T007, T008 (US1 skeleton) | US2 T017–T020 |

### Within Each User Story

- T004 (model) before T007 (widget consuming the model)
- T005 (service) before T007 (widget uses the service)
- T007 (StreamBuilder shell) before T008, T009, T021, T022
- T009 (layout) before T010, T011 (sub-components of layout)
- T011 (card decoration) before T012, T013 (card content)
- T014 (section header) and T015 (dashboard integration) can be done after T009

### Parallel Opportunities

- T005 and T006 can run in parallel (different files, both depend only on T004)
- T009 and T014 can run in parallel within US1 (layout vs. header)
- T010, T011 can run in parallel (axis vs. card decoration, different code blocks)
- T012 and T013 can run in parallel (image vs. text content in card)
- T017 and T019 can run in parallel within US2
- T021 and T022 can run in parallel within US3 (empty vs. error state)
- All Phase 6 tasks marked [P] can run in parallel

---

## Parallel Example: User Story 1

```
After T004 + T005 complete:

  Parallel group A:
    T006 — unit tests for Milestone model
    T007 — TimelineView StreamBuilder skeleton

  After T007:
  Parallel group B:
    T008 — loading state
    T009 — populated layout (Row structure)
    T014 — section header

  After T009:
  Parallel group C:
    T010 — central axis + heart nodes
    T011 — card BoxDecoration

  After T011:
  Parallel group D:
    T012 — conditional image rendering
    T013 — text content + date formatting

  Sequential:
    T015 — dashboard integration (needs T007–T013 complete)
    T016 — end-to-end Firestore seed validation
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (verify deps) — ~5 min
2. Complete Phase 2: Foundational (T004–T006) — ~30 min
3. Complete Phase 3: User Story 1 (T007–T016) — ~60 min
4. **STOP and VALIDATE**: Seed Firestore, run `flutter run`, verify timeline renders
5. Ship MVP — timeline is live, real-time (stream is always-on), and on-brand

### Incremental Delivery

1. Foundation (T004–T006) → Model + Service ready
2. US1 (T007–T016) → Styled timeline visible in dashboard ← **First visible value**
3. US2 (T017–T020) → Confirm live sync (likely already working from US1 stream)
4. US3 (T021–T023) → Empty + error states graceful
5. Polish (T024–T029) → Production-hardened

### Total Task Count

| Phase | Tasks | Parallelizable |
|-------|-------|---------------|
| Phase 1 — Setup | 3 | 1 |
| Phase 2 — Foundational | 3 | 2 |
| Phase 3 — US1 (MVP) | 10 | 6 |
| Phase 4 — US2 | 4 | 2 |
| Phase 5 — US3 | 3 | 2 |
| Phase 6 — Polish | 6 | 5 |
| **Total** | **29** | **18** |

---

## Notes

- `[P]` tasks operate on different files or independent code blocks — safe to run simultaneously
- `[Story]` label maps each task to its user story for traceability back to spec.md
- No new `pubspec.yaml` dependencies are required — all packages already present
- The `MilestoneService` stream lifecycle is managed by Flutter's `StreamBuilder` — no manual `dispose` needed in `TimelineView`
- The `DateFormat` import (`package:intl/intl.dart`) is a named import — no `initializeDateFormatting` call needed for `en` locale on Flutter Web
- Avoid adding `const` to widgets that consume theme values (`Colors.pink[X]`) as those are not compile-time constants
