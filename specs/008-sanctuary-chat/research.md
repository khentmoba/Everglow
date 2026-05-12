# Research: SanctuaryChat (Real-time Messaging)

## Decision: Authentication & State Update
- **Decision**: Update `AuthService` to include a `currentUser` string property.
- **Rationale**: `AuthService` is already used for Firebase Auth and is globally accessible via `Provider`. Adding `currentUser` here centralizes the identification logic.
- **Alternatives considered**:
    - `UserProvider`: Rejected to avoid over-engineering with too many providers.
    - Global variable: Rejected as it lacks reactivity and doesn't follow the project's existing `Provider` pattern.

## Decision: Gateway Logic
- **Decision**: Update `GatewayNotifier` in `gateway_state.dart` to validate both '1111' (clair) and '2222' (khent).
- **Rationale**: This is the existing entry point. We can leverage the `AuthService` within the `GatewayPage` or passed via dependency injection to set the user state.
- **Alternatives considered**:
    - Hardcoding '1111' and then asking for a name: Rejected as it's less seamless than the requested passcode-based differentiation.

## Decision: Chat UI Layout
- **Decision**: Use a `ListView.builder` with `ScrollController` for auto-scrolling. Align bubbles using `CrossAxisAlignment` in a `Column` wrapped in `Align`.
- **Rationale**: standard Flutter pattern for messaging apps. `animate_do` will be used for message appearance transitions.
- **Alternatives considered**:
    - `ListView(reverse: true)`: Rejected because the user specifically asked for "newest messages appear at the bottom" and "auto-scroll to the bottom", which is easier to reason about with a standard top-down list for small/medium history.

## Decision: Floating Button Placement
- **Decision**: Add a `FloatingActionButton` to `DashboardScreen`.
- **Rationale**: Since the `EverglowGuardian` occupies the bottom-right corner as a `Positioned` widget in a `Stack`, using the built-in `floatingActionButton` property of `Scaffold` provides a clean, standard, and accessible location that won't conflict with the Guardian's tap targets if positioned correctly.
- **Alternatives considered**:
    - `Positioned` in `Stack`: Rejected as it might overlap with the Guardian at `bottom: 24, right: 24`.
