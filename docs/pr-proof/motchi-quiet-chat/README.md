# Motchi — quiet, warm chat

All screenshots use synthetic conversations and a fake in-memory AI service. No sign-in, real messages, real memories, or live AI requests were used.

- `before-phone.png` / `after-phone.png`: same demo conversation at 390 × 844.
- `before-tablet.png` / `after-tablet.png`: same demo conversation at 820 × 1024.
- `before-welcome.png` / `after-welcome.png`: empty conversation at phone width.
- `large-type-phone.png`: 320 × 700 with 1.6× text. Welcome content scrolls rather than overflowing.

## Checks performed

- Opened the actual Motchi screen with `flutter run -d chrome` before and after the change.
- Typed and sent a demo message, observed thinking and Stop, stopped the reply, then opened New chat and observed the welcome screen.
- Changed Auto to Deep, opened history, opened More, and reached the fake Memory Book destination.
- Pasted a synthetic pink image, observed its attachment thumbnail, and removed it.
- Opened the extra-tools menu and observed Attach images, Voice input, and Canvas. Canvas toggling, real file-picker/microphone interaction, live AI, and live history were not verified locally.
- `flutter analyze --no-pub`: no issues.
- `flutter test --no-pub`: 1,387 tests passed. Browser-only tests are not included in this count.
- All 12 existing `tool/ci/check_*.dart` guards passed.
- `flutter build web --release --no-source-maps --no-pub`: production `lib/main.dart` build completed. The temporary demo entry point was removed first; the build used a locally-created, secret-free env placeholder, removed afterward.
- Browser widget tests were attempted, but Windows Flutter 3.44.4 failed during test bootstrap before running the suite: CanvasKit asset 404s and a mangled test path. The Motchi browser suite is now included in the existing Linux CI Chrome command, covering layout/keyboard space, thinking modes, Canvas, send/stop, new chat, and menu destinations.
