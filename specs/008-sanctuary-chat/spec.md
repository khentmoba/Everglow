# Feature Specification: SanctuaryChat (Real-time Messaging)

**Feature Branch**: `008-sanctuary-chat`  
**Created**: 2026-05-11  
**Status**: Draft  
**Input**: User description: "Build a real-time messaging feature for my Flutter web app, Everglow, using Firebase Cloud Firestore. I also need to update the entry gateway to differentiate between me and my girlfriend based on the passcode entered."

## Clarifications

### Session 2026-05-11
- Q: Should users be able to delete or edit their messages? → A: Messages are permanent once sent (no delete/edit).
- Q: Should messages have a "read" status or indicators? → A: No read receipts or "seen" indicators.
- Q: What should be displayed if there are no messages yet? → A: Show a cute heart icon and "Send the first message" text.
- Q: How should the chat UI look while the initial stream is loading? → A: A pulsing heart animation or "blooming" effect.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Personalized Entry (Priority: P1)

As a user (Khent or Clair), I want the application to recognize who I am when I enter my passcode so that my experience is personalized and the messaging system knows who the sender is.

**Why this priority**: Fundamental for the messaging feature to function correctly (sender identification) and provides a personalized "welcome" feel to the sanctuary.

**Independent Test**: Enter '1111' at the gateway and verify state is 'clair'. Enter '2222' and verify state is 'khent'.

**Acceptance Scenarios**:

1. **Given** the gateway screen, **When** I enter '1111', **Then** the app unlocks and sets the global user to 'clair'.
2. **Given** the gateway screen, **When** I enter '2222', **Then** the app unlocks and sets the global user to 'khent'.

---

### User Story 2 - Real-time Sanctuary Messaging (Priority: P1)

As a resident of the sanctuary, I want to send and receive messages in real-time so that I can stay connected with my partner through our private digital space.

**Why this priority**: Core functionality of the requested feature.

**Independent Test**: Send a message from one session (as 'khent') and verify it appears instantly in another session (as 'clair').

**Acceptance Scenarios**:

1. **Given** I am on the SanctuaryChat screen, **When** I type a message and press send, **Then** the message is persisted to the database with my name as the sender.
2. **Given** I am on the SanctuaryChat screen, **When** a new message arrives in the database, **Then** it appears at the bottom of the list instantly.
3. **Given** the message list is long, **When** a new message arrives, **Then** the view automatically scrolls to show the latest message.

---

### User Story 3 - Aesthetic Chat Interface (Priority: P2)

As a user, I want the chat bubbles to be visually distinct and follow the "pinkish and cute" theme so that the communication feels warm and personal.

**Why this priority**: Essential for the "Everglow" brand and user experience.

**Independent Test**: View the chat screen and verify that my messages are on the right (deeper pink) and partner messages are on the left (soft pink/white) with "tail" effects on the bubbles.

**Acceptance Scenarios**:

1. **Given** a message I sent, **When** viewed in the chat, **Then** it is aligned to the right with a deeper pink background.
2. **Given** a message from my partner, **When** viewed in the chat, **Then** it is aligned to the left with a soft pink/white background.
3. **Given** any message bubble, **When** rendered, **Then** it has a high border radius (24.0) except for the corner closest to the sender.

---

### User Story 4 - Seamless Navigation (Priority: P3)

As a user on the dashboard, I want a quick way to access our chat so that I don't have to navigate through complex menus.

**Why this priority**: Enhances usability and accessibility of the chat feature.

**Independent Test**: Tap the chat bubble icon on the dashboard and verify smooth transition to SanctuaryChat.

**Acceptance Scenarios**:

1. **Given** the main dashboard, **When** I tap the floating heart/chat button, **Then** I am navigated to the SanctuaryChat screen with a smooth slide or fade transition.

---

### Edge Cases

- **Offline Mode**: What happens when a user tries to send a message without an internet connection? (Assumption: Firestore will queue it, but UI should ideally show a "sending" state).
- **Empty Messages**: How does the system handle sending an empty or whitespace-only message? (Requirement: Should be blocked).
- **Message Overload**: How does the system handle hundreds of messages? (Requirement: Implement efficient list rendering/paging if needed, though for a private chat, simple list might suffice for now).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST update global user state based on the specific passcode ('1111' -> 'clair', '2222' -> 'khent').
- **FR-002**: System MUST persist messages to a Firestore collection named `messages`.
- **FR-003**: System MUST provide a real-time stream of messages ordered chronologically (ascending).
- **FR-004**: Each message MUST contain `sender`, `text`, and `timestamp` fields.
- **FR-005**: The chat UI MUST differentiate sender alignment and color (Right/Deep Pink for self, Left/Soft Pink for other).
- **FR-006**: The chat bubbles MUST implement a "tail" effect by varying corner border radiuses.
- **FR-007**: The chat view MUST automatically scroll to the latest message upon arrival.
- **FR-008**: The input area MUST be fixed at the bottom with a rounded design and a paper plane/heart send icon.
- **FR-009**: A floating chat button MUST be added to the Main Dashboard for quick access.
- **FR-010**: System MUST use **Provider** for global user state management.
- **FR-011**: Chat messages MUST be **permanent** (no delete/edit functionality).
- **FR-012**: Chat UI MUST display a **pulsing heart animation** during initial message stream loading.
- **FR-013**: Chat UI MUST display a heart icon and "Send the first message" text when no messages exist.
- **FR-014**: Chat UI MUST NOT display read receipts or "seen" indicators.

### Key Entities *(include if feature involves data)*

- **ChatMessage**: Represents a single piece of communication.
    - `id`: Unique identifier (Firestore document ID).
    - `sender`: String identifier of the user who sent it ('clair' or 'khent').
    - `text`: The message content.
    - `timestamp`: When the message was sent (for ordering).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Message delivery latency (send to appear on partner's device) is under 2 seconds under normal network conditions.
- **SC-002**: 100% of messages are correctly attributed to the sender identified at the gateway.
- **SC-003**: Navigation from dashboard to chat takes less than 500ms for the transition to complete.
- **SC-004**: The UI perfectly matches the requested "tail" bubble design with 24.0 radius on 3 corners.

## Assumptions

- **Shared Device**: The app is designed for a shared or private device where the passcode serves as the "login" mechanism.
- **Internet Connectivity**: Users have a stable internet connection for real-time Firestore sync.
- **Existing Dashboard**: A "Main Dashboard" already exists with a location suitable for a floating button.
- **Theme**: The app has an existing theme system that can be extended for these specific colors (Colors.pink[300], Colors.pink[50]).
