# Implementation Tasks: Dynamic Letterbox

**Feature Branch**: `003-dynamic-letterbox`
**Spec**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md)

## Implementation Strategy

We will build the feature incrementally, starting with the data model and UI foundation, followed by user interactions.
1. **Phase 1-2 (MVP Foundation)**: Data model and placeholder data.
2. **Phase 3 (Visual Layout)**: Building the horizontal scrolling list and note cards.
3. **Phase 4-5 (Interactions)**: Opening notes (with dialogs) and handling locked states.
4. **Phase 6**: Polish and integration.

## Tasks

### Phase 1: Setup

- [x] T001 Ensure `google_fonts` is added to `pubspec.yaml`

### Phase 2: Foundational

- [x] T002 Create `HiddenNote` model in `lib/features/dashboard/domain/models/hidden_note.dart` with `id`, `title`, `content`, `unlockDate`, `isRead`, `isUnlocked` getter, and a dummy list of 3-4 instances.

### Phase 3: User Story 1 - Viewing the Letterbox List

**Goal**: Display a horizontal scrolling list of digital envelopes below the anniversary metric section on the main dashboard.
**Independent Test**: The grid or list of envelope cards with high border radiuses and soft shadows is visible on the dashboard and shows dummy data.

- [x] T003 [P] [US1] Create `NoteCard` widget in `lib/features/dashboard/presentation/widgets/note_card.dart` to render locked, unread, and read envelope states based on a `HiddenNote` instance.
- [x] T004 [US1] Create `LetterboxView` widget in `lib/features/dashboard/presentation/widgets/letterbox_view.dart` using a horizontal `ListView.builder` of `NoteCard` widgets.
- [x] T005 [US1] Update `lib/features/dashboard/presentation/pages/dashboard_page.dart` (or the equivalent main layout file) to insert `LetterboxView` exactly below the `MetricCard`.
- [x] T006 [P] [US1] Write widget test for `LetterboxView` in `test/features/dashboard/presentation/widgets/letterbox_view_test.dart` to verify rendering without overflow.

### Phase 4: User Story 2 - Interacting with Unlocked Notes

**Goal**: Open an unlocked note to read the hidden message inside a cute 'letter' UI.
**Independent Test**: Tapping an unlocked note displays the dialog with the scale-in animation and handwritten font. Long text can be scrolled.

- [x] T007 [US2] Create `NoteDialog` widget in `lib/features/dashboard/presentation/widgets/note_dialog.dart` using `ConstrainedBox` and `SingleChildScrollView` for long text, styled with a handwritten font.
- [x] T008 [US2] Update `NoteCard` to wrap the UI in `GestureDetector`/`InkWell` and trigger `showGeneralDialog` with `NoteDialog` when tapped (if unlocked).
- [x] T009 [US2] Implement logic to mark the `HiddenNote` as read (`isRead = true`) when the dialog is opened and trigger UI rebuild.
- [x] T010 [P] [US2] Write widget test for `NoteDialog` in `test/features/dashboard/presentation/widgets/note_dialog_test.dart` to ensure it scrolls and displays text correctly.

### Phase 5: User Story 3 - Attempting to Open Locked Notes

**Goal**: Prevent peeking at locked notes with a playful rejection message.
**Independent Test**: Tapping a locked note displays the playful rejection alert instead of opening the note.

- [x] T011 [US3] Update `NoteCard` tap logic in `lib/features/dashboard/presentation/widgets/note_card.dart` to show a playful `SnackBar` or `AlertDialog` when the tapped note is locked.

### Phase 6: Polish & Cross-Cutting Concerns

- [x] T012 Verify all UI elements (NoteCard, NoteDialog) inherit the global cute theme (high border radiuses, soft shadows, colors).
- [x] T013 Ensure smooth transitions and 60fps animations.

## Dependencies

- **US1** requires **Phase 2 (Foundational)** to be complete.
- **US2** requires **US1** to be complete.
- **US3** requires **US1** to be complete (can be done in parallel with US2).

## Parallel Execution Opportunities

- Model creation (T002) and UI prototyping (T003) can be started simultaneously if mock data is used in the UI temporarily.
- `LetterboxView` test (T006) and `NoteDialog` test (T010) can be written independently of other tasks once their widgets are drafted.
- US2 and US3 can be implemented in parallel since they touch different logical branches of the `GestureDetector` tap handler in `NoteCard`.
