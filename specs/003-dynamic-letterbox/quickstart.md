# Quickstart: Dynamic Letterbox

To work on or test the Dynamic Letterbox feature:

1. Locate the dummy data in `lib/features/dashboard/domain/models/hidden_note.dart`.
2. To test the locked state, ensure one of the dummy notes has an `unlockDate` set to `DateTime.now().add(const Duration(days: 1))`.
3. To test the unread unlocked state, ensure one of the dummy notes has an `unlockDate` set to a past date and `isRead: false`.
4. To test the read unlocked state, ensure one of the dummy notes has an `unlockDate` set to a past date and `isRead: true`.
5. Run the Flutter web application (`flutter run -d chrome`).
6. Navigate to the main dashboard.
7. Observe the horizontal list of envelopes directly below the `MetricCard`.
8. Tap a locked note to see the playful rejection alert.
9. Tap an unread unlocked note to see the scale-in dialog and verify the read state updates.
