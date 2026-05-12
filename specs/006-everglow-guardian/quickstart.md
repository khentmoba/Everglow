# Quickstart: Everglow Guardian

## Development Setup

1. **Messages Seed**:
   - Create `assets/data/guardian_messages_seed.json`.
   - Add initial messages: "Happy to see you!", "Everything is pink today!", "I missed you, Clair!".
   - Ensure the asset is registered in `pubspec.yaml`.

2. **Service Initialization**:
   - Call `GuardianService().initialize()` during the dashboard's initial load sequence (similar to `DateIdeaService`).

3. **Dashboard Integration**:
   - Locate the `Stack` in `DashboardScreen` (or main layout).
   - Add `EverglowGuardian()` as the last child to ensure it floats above other content.

## Verification Steps

1. **Manual Test**:
   - Open the dashboard and verify the character appears at the bottom-right.
   - Observe the idle floating animation.
   - Tap the character and verify the reaction animation and heart particles.
   - Wait 3-7 minutes or tap to see the thought bubble appear.

2. **Automated Test**:
   - Run `flutter test tests/unit/guardian_service_test.dart` to verify seeding and random selection.
   - Run `flutter test tests/widget/everglow_guardian_test.dart` to verify animation triggers.
