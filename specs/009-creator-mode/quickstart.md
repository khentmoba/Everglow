# Quickstart: Creator Mode

**Feature**: Creator Mode Admin Panel | **Date**: 2026-05-11

## For Developers

### Prerequisites
1.  **Firebase Storage**: Ensure a Storage bucket is initialized in the Firebase Console.
2.  **Dependencies**: Check `pubspec.yaml` for:
    - `image_picker: ^1.0.0`
    - `firebase_storage: ^11.0.0`

### Integration
- The `CreatorModal` is triggered from the `DashboardScreen`.
- It uses the `AuthService` to check if the current user is 'khent'.

## For Admins (Khent)

### How to use
1.  **Access**: Log in with passcode `2222`.
2.  **Trigger**: Look for the discrete floating action button or icon in the top navigation bar.
3.  **Form**: Choose between "Memory" and "Letter" tabs.
4.  **Save**: Fill in the fields, pick an image (if needed), and tap "Save to Everglow ✨".
5.  **Sync**: The content will appear immediately in the Timeline or Letterbox for both you and Clair.
