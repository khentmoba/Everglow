# Quickstart: Gamified Pink UI Modernization

## 1. Setup Theme Tokens
Initialize the new `AppTheme` class in `lib/core/theme/`.

```dart
class AppTheme {
  static const pinkShimmer = LinearGradient(
    colors: [Color(0xFFFFD1DC), Color(0xFFFF00FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const glassBorder = Color(0x80F7E7CE); // Gold with opacity
}
```

## 2. Implement GlassContainer
Use the base `GlassContainer` in `lib/shared/widgets/`.

```dart
GlassContainer(
  child: MyCardContent(),
  blur: 10.0,
  opacity: 0.1,
)
```

## 3. Initialize XP Service
Ensure `XPService` is initialized in `main.dart` to start listening to Firestore progress.

```dart
final xpService = XPService();
await xpService.initialize(currentUser.uid);
```

## 4. Performance Check
Verify fallback logic by enabling "Reduced Motion" on your device or setting `forceLowPerformanceMode` to true in `ThemeController`.
