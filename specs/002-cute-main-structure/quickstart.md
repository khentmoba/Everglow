# Quickstart: Cute Main Structure

## Setup Instructions

1. Ensure the `age_calculator` package (or equivalent) is added to `pubspec.yaml`:
   ```yaml
   dependencies:
     flutter:
       sdk: flutter
     age_calculator: ^1.0.0
   ```
2. Run `flutter pub get` to install dependencies.

## Key Components

- **`main.dart`**: Contains the global `ThemeData` configuration (Colors.pink[50] background, Colors.pink[200] interactives, Quicksand/Bubblegum Sans font, and global `CardTheme` / `ButtonTheme` with `borderRadius` 32.0).
- **`GatewayTransition`**: Custom `PageRouteBuilder` handling the scale and fade blooming effect.
- **`DashboardScreen`**: Organic `Scaffold` layout featuring a staggered/spaced list and the heart-shaped `FloatingActionButton`.
- **`MetricCard`**: Widget responsible for displaying the `AnniversaryCounter` state and using `AnimatedSwitcher` for ticking digits.
