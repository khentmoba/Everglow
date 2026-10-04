# Motchi — quiet, warm chat

All screenshots use synthetic conversations and a fake in-memory AI service. No sign-in, real messages, real memories, or live AI requests were used.

## Latest refinement

- `refined-phone.png` / `refined-welcome.png`: conversation and welcome at 390 × 844.
- `refined-tablet.png` / `refined-welcome-tablet.png`: 820 × 1024.
- `refined-large-type-phone.png` / `refined-large-type-scrolled.png`: 320 × 700 with 1.6× text, before and after scrolling to reach all four prompts.
- `refined-history.png`: history drawer with the same synthetic movie-night conversation.

The second pass replaces the prompt pills with full-width rows, uses the already-bundled regular DM Sans for reading, removes ornamental markdown accents in Motchi, and gives the composer and history drawer the same quieter style. Cat badges, avatar glows, rainbow buttons, the decorative “LIVE” badge, and the unsupported “Synced” claim are gone. The current conversation still says “Active now”. A single thinking label and animated dots replace the rotating filler phrases.

The original `before-*.png`, `after-*.png`, and `large-type-phone.png` are retained to show the first pass; they are not the latest design.

## Checks performed

- Opened the actual Motchi screen with `flutter run -d chrome`, the production theme, and synthetic providers. Inspected phone, tablet, and large-text screenshots, then scrolled the small large-text viewport to reach the fourth prompt.
- Clicked Pick a movie, observed its exact prompt and thinking/Stop state, then stopped the reply and opened New chat.
- Typed and sent a synthetic message and stopped generation.
- Changed Auto to Deep, opened extra tools, and toggled Canvas; the enabled Canvas control appeared.
- Clicked Quiz us and observed Canvas turning on automatically.
- Opened history and selected the synthetic current conversation; the drawer closed and the conversation remained visible.
- Chrome CDP captured no application exceptions during these interactions.
- `flutter analyze --no-pub`: no issues.
- `flutter test --no-pub`: 1,388 passed. Browser-only tests are not included in this count.
- All 12 existing `tool/ci/check_*.dart` guards passed.
- `flutter build web --release --no-source-maps --no-pub`: production `lib/main.dart` build completed after removing the demo entry. It used a locally-created, secret-free env placeholder, removed afterward.
- Native regression tests retain default Study markdown styling and check that plain chat keeps formatting without decorative gradients/glows. Sidebar tests retain stream updates, search, summaries and the current-chat marker.
- The Motchi Chrome suite covers responsive layout/keyboard space, thinking modes, Canvas, send/stop, new chat, destinations, and all four prompt rows. Prompt target heights are checked with a compact theme too.

## Verification limits

Windows Flutter 3.44.4 browser tests remain blocked during bootstrap (CanvasKit asset 404s and a mangled test path). The earlier `c8ae20e` revision passed all 11 Linux Chrome tests; the new revision adds a prompt-row test and awaits fresh CI. Manual Chrome checks above are separate from that automated result.

Real microphone/file-picker interaction, live AI, live history, and private-account behavior were not tested. No production deployment or merge was performed.
