# Quickstart: Daily Bloom

This guide provides a quick setup for developers working on the Daily Bloom feature.

## 1. Prerequisites

- Firebase Project configured and `google-services.json` / `firebase_options.dart` present.
- Existing user authentication flow functional.
- `Letterbox` feature integrated (for interaction hooks).

## 2. Integration Steps

### A. GardenService Setup
Ensure the `GardenService` is initialized in your `main.dart` or via a `MultiProvider`.

```dart
ChangeNotifierProvider(create: (_) => GardenProvider()),
```

### B. Dashboard Integration
Place the `DailyBloom` widget in `DashboardScreen` immediately following the `TimelineView`.

```dart
Column(
  children: [
    TimelineView(),
    DailyBloom(), // New feature
  ],
)
```

### C. Interaction Hook
Trigger an interaction on every dashboard visit:

```dart
@override
void initState() {
  super.initState();
  context.read<GardenProvider>().recordVisit();
}
```

## 3. Growth Testing
To manually test different growth stages, modify the `totalInteractions` field in Firestore for the current user:

1. Navigate to `users/{uid}/garden_stats/stats` in Firebase Console.
2. Update `totalInteractions` to `5`, `10`, `20`, or `30`.
3. Refresh the web app to see the lily transform.
