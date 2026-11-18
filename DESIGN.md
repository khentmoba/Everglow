# Design

The look Everglow already has, and keeps. Khent's word "redesign" means
**refine this world**: richer page bodies, better hierarchy, more polish.
It never means a new palette, new fonts, or a new mood. Four mock-ups that
threw the identity away were rejected as "insanely worse" (2026-11-18), and
a pass that only touched shared headers was rejected as "mostly no changes".

## Identity (fixed)

- **Mood:** night-time, warm, intimate. Clair opens it on her phone in a
  dim room.
- **Ground:** deep night purples: `inkDeep`, `twilight`, `velvet`, `plum`,
  `silk`.
- **Love colour:** rose: `deepRose`, `roseQuartz`, `auroraRose`.
- **Accent:** gold: `blushGold`, `auroraGold`; lilac and teal aurora tints
  for highlights.
- **Type:** Cormorant Garamond for display, Outfit for UI and body, Caveat
  and Dancing Script for handwritten touches, DM Sans for long reading.
- **Mascot:** the Motchi cat.
- All values live in `react/src/core/theme/` (`colors.ts`, `typography.ts`,
  `paint.ts`, `motion.ts`). Use the tokens and never hardcode a colour.

## Separate worlds

Cinema (Netflix-inspired, `cinemaRed`), Anime, Books and Mangacelestia keep
their own looks. Cinema is shared with family guests, so its words stay
neutral.

## What a good change looks like

- Bodies change, not only headers: cards, lists, empty states, spacing.
- Built for phone (about 430px) first, then tablet (820px). Check grids and
  aspect-ratio tiles at 820px, where a 2x2 gallery tile once collapsed.
- Before/after shots of the same screen make the difference obvious.
