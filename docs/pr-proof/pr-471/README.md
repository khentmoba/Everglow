# PR-471 Proof — Motchi Replying & Thinking Animations

Fake demo data only. No real couple data.

## What changed

When Motchi was replying, the chat looked completely static and bland:
- The avatar halo was nearly invisible behind the 20px avatar, and the avatar itself did not animate.
- There was no status or typing indicator beside Motchi's name.
- The streaming caret was placed in a horizontal `Row` alongside `Expanded(_MarkdownText)`, which pinned it to the top-right corner of the whole message block rather than where text was streaming.

Both the Anime Motchi sidebar (`animex_motchi_sidebar.dart`) and the Main Motchi chat (`motchi_widgets_streaming.dart`, `motchi_widgets_extra.dart`) now have coordinated, lively animations:

1. **Lively Answering Avatar (`_AnsweringAvatar` & `_AnimeAnsweringAvatar`)**:
   - Outer soft diffuse glow bloom (`auroraRose` + `blushGold`).
   - Gentle breathing scale pulse (1.0 -> 1.06) on the avatar itself with a pulsing rose shadow.
   - Retains the exact `motchi-answering-halo` container and animated alpha gradient for test continuity.

2. **Replying / Thinking Badge (`_ReplyingBadge` & `_AnimeReplyingBadge`)**:
   - Rendered beside Motchi's name while in flight.
   - Shows `thinking` with pulsing dot and bouncing micro-dots while waiting for the first token.
   - Switches to `replying` with pulsing dot and bouncing micro-dots while streaming text.
   - Disappears smoothly once streaming completes.

3. **Stream Tail Indicator (`_StreamingTailIndicator` & `_AnimeStreamingTailIndicator`)**:
   - Positioned cleanly below the streamed text in the column (replacing the misplaced top-right row caret).
   - Features a blinking blush-gold cursor with soft glow + 3 animated waving rose-quartz micro-dots.
   - Disappears once the reply is complete.

4. **Reduced Motion**:
   - All animations check `AppMotion.reduced` and fall back to static fills and opacities when reduced motion is preferred.

## Proof (Fake demo data)

- `shot-anime-motchi-replying.png`: Motchi streaming anime recommendations with breathing avatar, `replying` badge, and stream tail indicator.
- `shot-anime-motchi-thinking.png`: Initial in-flight state with breathing avatar, `thinking` badge, and bouncing thinking dots.

## Verification

- `flutter analyze` — clean (no issues).
- `flutter test test/features/anime/animex_motchi_sidebar_test.dart` — 11 passed (including new replying/thinking animation test).
- `flutter test test/features/anime/` — 207 passed.
- `flutter test test/features/ai/` — 126 passed.
- All `dart tool/ci/check_*.dart` guards passed cleanly.
