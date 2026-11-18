import type { CSSProperties } from 'react';
import { AppColors } from '../../core/theme/colors';
import { lineHeight } from '../../core/theme/paint';
import { Fonts } from '../../core/theme/typography';

export const KatanaColors = {
  background: '#060408',
  surface: '#0E0912',
  surfaceAlt: '#170E1D',
  surfaceGlow: '#211229',
  border: '#2E1726',
  borderStrong: '#52213B',
  text: '#FFF5F8',
  textMuted: '#D9B8C7',
  textLight: '#997586',
  accent: '#FF2E7E',
  accentDark: '#C9185B',
  accentSoft: '#FF85B3',
  link: '#FF85B3',
  green: AppColors.success,
  orange: '#FF5C99',
  headerDark: '#09060C',
} as const;

// Flutter merges these into bodyMedium, so a style with no height keeps
// 20/14 and every line rounds to a whole pixel.
export const KatanaType = {
  title: { fontFamily: Fonts.body, fontWeight: 600, color: KatanaColors.text, fontSize: 16, lineHeight: lineHeight(16, 1.25) },
  heading: { fontFamily: Fonts.body, fontWeight: 600, color: KatanaColors.text, fontSize: 22, lineHeight: lineHeight(22, 1.2) },
  section: { fontFamily: Fonts.body, fontWeight: 600, color: KatanaColors.text, fontSize: 17, lineHeight: lineHeight(17, 1.2) },
  body: { fontFamily: Fonts.body, fontWeight: 500, color: KatanaColors.textMuted, fontSize: 13.5, lineHeight: lineHeight(13.5, 1.55) },
  small: { fontFamily: Fonts.body, fontWeight: 500, color: KatanaColors.textLight, fontSize: 12, lineHeight: lineHeight(12) },
  link: { fontFamily: Fonts.body, fontWeight: 600, color: KatanaColors.link, fontSize: 13, lineHeight: lineHeight(13) },
  accent: { fontFamily: Fonts.body, fontWeight: 600, color: KatanaColors.accent, fontSize: 13, lineHeight: lineHeight(13) },
} satisfies Record<string, CSSProperties>;
