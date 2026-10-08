# Small UI fallback fonts

The text fonts remain Cormorant Garamond, Outfit, Caveat, Dancing Script,
Bebas Neue and DM Sans. `Everglow Emoji` / `Everglow Symbols` are only fallbacks
for common emoji and decorative symbols absent from the text font.

Flutter Web otherwise discovers these glyphs as each card first appears,
downloads several Noto subsets and repeatedly rebuilds its font collection.
The small bundled sets are loaded with the existing font manifest instead.
They do not disable normal fallback: uncommon user emoji and other languages
can still fetch Flutter's regular fallback fonts. This is deliberately not a
full Unicode font pack, nor a promise that every font-related stall is gone.

- Emoji: 154 code points, subset of Google Noto's **2D** COLRv1 font v2.051,
  commit `f3ae03f5e9b3b8516fa151f7168159ca1a3e7515` (not the later 3D artwork).
- Symbols: 8 code points (bullet, separator, rectangle, star, outline heart,
  tick, cross, four-point star), Noto Sans Symbols 2 v24.
- Original copyright/license records are retained in both fonts; complete SIL
  OFL 1.1 licenses ship alongside them as `assets/google_fonts/OFL-everglow-*.txt`.
- Internal families are renamed to Everglow Emoji / Everglow Symbols; PostScript
  names omit spaces. Font family aliases match `pubspec.yaml`.

## Rebuild

Development-only requirements: Python, fontTools and Brotli (for the WOFF2
source). Neither package is an application dependency or needed by ordinary CI.

```sh
python -m pip install fonttools==4.54.1 brotli
python tool/subset_ui_fonts.py
```

The script verifies pinned upstream SHA-256 hashes, preserves license metadata,
subsets from the checked-in code-point lists and avoids timestamp-based output
changes. The lists were derived from literal/escaped characters in existing
Dart app copy; no live/private couple content or environment files are inputs.
Skin-tone modifiers, joiners, flags and keycap components used by those glyphs
are retained. FontTools retains layout/color glyph dependencies automatically.

When adding UI characters, only extend the list after checking the source font
covers them, rebuild, and verify the appearance and fallback requests in a
release browser. Rebuild is optional: a character outside the list still uses
Flutter's normal fallback, but can reintroduce a first-use pause.

Test wiring: `flutter test test/core/theme/emoji_font_fallback_test.dart`.
Cold-scroll measurements and limits: `../pr-proof/dashboard-cold-fonts/README.md`.
