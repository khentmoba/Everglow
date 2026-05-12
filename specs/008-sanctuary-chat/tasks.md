# Tasks: SanctuaryChat (Real-time Messaging)

**Input**: Design documents from `/specs/008-sanctuary-chat/`
**Prerequisites**: [plan.md](file:///c:/APPLICATIONS/Everglow/specs/008-sanctuary-chat/plan.md), [spec.md](file:///c:/APPLICATIONS/Everglow/specs/008-sanctuary-chat/spec.md), [research.md](file:///c:/APPLICATIONS/Everglow/specs/008-sanctuary-chat/research.md), [data-model.md](file:///c:/APPLICATIONS/Everglow/specs/008-sanctuary-chat/data-model.md)

**Tests**: Tests are NOT requested in the specification. Manual verification will be used.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and basic structure

- [x] T001 [P] Create feature directory structure in `lib/features/chat/`
- [x] T002 [P] Verify `provider` and `cloud_firestore` are correctly linked in `lib/main.dart`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [x] T003 Update `AuthService` in `lib/services/auth_service.dart` to include `currentUser` string and notify listeners
- [x] T004 Update `GatewayNotifier` in `lib/features/entry/presentation/state/gateway_state.dart` to support dual passcodes ('1111', '2222')

**Checkpoint**: Foundation ready - user story implementation can now begin in parallel

---

## Phase 3: User Story 1 - Personalized Entry (Priority: P1) 🎯 MVP

**Goal**: Identify 'clair' or 'khent' based on the passcode entered at the gateway.

**Independent Test**: Enter '1111' at the gateway; verify app unlocks and internal state shows 'clair'.

### Implementation for User Story 1

- [x] T005 [US1] Update `GatewayPage` in `lib/features/entry/presentation/pages/gateway_page.dart` to set `currentUser` in `AuthService` on successful validation

**Checkpoint**: User Story 1 functional - app now knows who is entering.

---

## Phase 4: User Story 2 - Real-time Sanctuary Messaging (Priority: P1) 🎯 MVP

**Goal**: Core real-time messaging functionality.

**Independent Test**: Send a message as 'clair'; verify it appears in Firestore and then in the UI for 'khent'.

### Implementation for User Story 2

- [x] T006 [P] [US2] Create `ChatMessage` model in `lib/features/chat/domain/models/chat_message.dart` with `fromFirestore` and `toMap`
- [x] T007 [US2] Create `ChatService` in `lib/features/chat/data/services/chat_service.dart` with `getMessagesStream()` and `sendMessage()`
- [x] T008 [US2] Create basic `SanctuaryChatScreen` scaffold in `lib/features/chat/presentation/screens/sanctuary_chat_screen.dart` with `ListView.builder`
- [x] T009 [US2] Implement message sending logic and text input in `lib/features/chat/presentation/screens/sanctuary_chat_screen.dart`

**Checkpoint**: User Story 2 functional - messages can be sent and received in real-time.

---

## Phase 5: User Story 3 - Aesthetic Chat Interface (Priority: P2)

**Goal**: Premium "pinkish and cute" chat UI with tails and animations.

**Independent Test**: Open chat; verify pulsing heart loader, custom bubble tails, and auto-scroll on new message.

### Implementation for User Story 3

- [x] T010 [P] [US3] Create `ChatBubble` widget in `lib/features/chat/presentation/widgets/chat_bubble.dart` with alignment logic and "tail" border radiuses
- [x] T011 [US3] Add pulsing heart loader and empty state heart icon in `lib/features/chat/presentation/screens/sanctuary_chat_screen.dart`
- [x] T012 [US3] Implement `ScrollController` auto-scroll logic in `lib/features/chat/presentation/screens/sanctuary_chat_screen.dart`
- [x] T013 [US3] Add `animate_do` entrance animations to messages in `lib/features/chat/presentation/widgets/chat_bubble.dart`

**Checkpoint**: User Story 3 functional - chat looks and feels premium.

---

## Phase 6: User Story 4 - Seamless Navigation (Priority: P3)

**Goal**: Quick access to chat from the dashboard.

**Independent Test**: Tap the heart FAB on the dashboard; verify smooth transition to chat.

### Implementation for User Story 4

- [x] T014 [US4] Add `FloatingActionButton` to `DashboardScreen` in `lib/features/dashboard/presentation/screens/dashboard_screen.dart`
- [x] T015 [US4] Implement `Navigator.push` with slide/fade transition to `SanctuaryChatScreen` in `lib/features/dashboard/presentation/screens/dashboard_screen.dart`

**Checkpoint**: All user stories complete.

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Final touches and verification

- [x] T016 [P] Verify Firestore rules allow the new `messages` collection
- [x] T017 Final manual verification across 'clair' and 'khent' roles
- [x] T018 Code cleanup and removal of any debug prints

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies.
- **Foundational (Phase 2)**: Depends on Phase 1 - BLOCKS US1.
- **US1 (Phase 3)**: Depends on Phase 2 - BLOCKS sender identification in US2.
- **US2 (Phase 4)**: Depends on US1.
- **US3 (Phase 5)**: Depends on US2.
- **US4 (Phase 6)**: Depends on US2.
- **Polish (Phase 7)**: Depends on all stories.

### Parallel Opportunities

- T001, T002 can run together.
- T006 can be created while T005 is in progress.
- T010 can be developed in parallel with US2 logic if the contract is known.

---

## Implementation Strategy

### MVP First (US1 + US2)
1. Complete Foundational.
2. Complete US1 (Entry).
3. Complete US2 (Messaging).
4. **STOP and VALIDATE**: Real-time sync works.

### Incremental Delivery
1. Add US3 (Aesthetics) once core logic is stable.
2. Add US4 (Navigation) as the final entry point.
