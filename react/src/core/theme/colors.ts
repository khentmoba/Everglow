// Same values as lib/core/theme/app_colors.dart. Keep the two in step until
// the Flutter app is retired.
export const AppColors = {
  twilight: '#1A1A2E',
  velvet: '#2D1B33',
  roseQuartz: '#F4C2C2',
  deepRose: '#C2185B',
  blushGold: '#E8D5B7',
  petalWhite: '#FFF5F5',
  softLavender: '#D4B5D6',
  moonlight: '#F0E6FF',
  warmAmber: '#F0A500',

  auroraRose: '#FF6F91',
  auroraGold: '#F5C97B',
  auroraLilac: '#B79CED',
  auroraTeal: '#7EE8D2',
  inkDeep: '#100A1C',
  plum: '#3A2352',
  silk: '#2E203E',

  deepBlack: '#12091A',
  mutedPurple: '#8A7A92',
  goldShadow: '#6B4E00',
  rosePressed: '#8E1444',
  roseDark: '#6B0F2A',
  roseDepths: '#7A2442',
  shimmerBase: '#1C1228',
  shimmerHighlight: '#2A1F3A',
  cinemaRed: '#E50914',
  cinemaMatch: '#7ED69A',
  cinemaOrange: '#FF6D00',
  cinemaPink: '#E91E8C',
  cinemaGreen: '#2E7D32',
  cinemaAmber: '#FF9800',
  cinemaBlue: '#1976D2',
  animeGold: '#E8C97A',
  animeCyan: '#00BCD4',

  error: '#E5739B',
  success: '#4ADE80',
  black: '#000000',
  /** Flutter's `Colors.transparent` is transparent black, which matters for gradients. */
  transparent: '#00000000',
  orange700: '#F57C00',
} as const;

export type Rgba = [r: number, g: number, b: number, a: number];

/** Reads `#RRGGBB`, `#RRGGBBAA` or `rgba(r, g, b, a)`. */
export function parse(color: string): Rgba {
  // Flutter's Colors.transparent is transparent black.
  if (color === 'transparent') return [0, 0, 0, 0];
  if (color.startsWith('rgb')) {
    const [r, g, b, a = 1] = color.slice(color.indexOf('(') + 1, -1).split(',').map(Number);
    return [r, g, b, a];
  }
  const hex = color.replace('#', '');
  const r = parseInt(hex.slice(0, 2), 16);
  const g = parseInt(hex.slice(2, 4), 16);
  const b = parseInt(hex.slice(4, 6), 16);
  const a = hex.length === 8 ? parseInt(hex.slice(6, 8), 16) / 255 : 1;
  return [r, g, b, a];
}

/** Flutter's `color.withValues(alpha: a)`: replaces the alpha. */
export function withAlpha(color: string, a: number): string {
  const [r, g, b] = parse(color);
  return css([r, g, b, a]);
}

export function css([r, g, b, a]: Rgba): string {
  return `rgba(${r}, ${g}, ${b}, ${Math.round(a * 10000) / 10000})`;
}

/** Derived colors from AppColors getters. */
export const Derived = {
  surfaceGlass: withAlpha(AppColors.moonlight, 0.12),
  panelGlass: withAlpha(AppColors.inkDeep, 0.62),
  glassSoft: withAlpha(AppColors.moonlight, 0.08),
  textMuted: withAlpha(AppColors.roseQuartz, 0.76),
  textMedium: withAlpha(AppColors.petalWhite, 0.82),
  textHigh: withAlpha(AppColors.petalWhite, 0.95),
  textDisabled: withAlpha(AppColors.petalWhite, 0.52),
  border: withAlpha(AppColors.moonlight, 0.18),
  divider: withAlpha(AppColors.moonlight, 0.18),
  glowRose: withAlpha(AppColors.deepRose, 0.35),
};

/** The Material 3 dark scheme Flutter seeds from deepRose (AppTheme.gamifiedTheme). */
export const M3Scheme = {
  onSurface: '#EFDEE0',
  onSurfaceVariant: '#D6C2C4',
  outline: '#9E8C8F',
  onPrimary: '#650033',
  white70: 'rgba(255,255,255,0.7)',
};

export const AppArt = {
  leaf: '#66BB6A',
  leafLight: '#81C784',
  stem: '#4CAF50',
  stemDark: '#388E3C',
  stemOlive: '#558B2F',
  leafOlive: '#7CB342',
  bark: '#5D4037',
  barkLight: '#8D6E63',
  barkDeep: '#795548',
  tulipPotLight: '#B3E5FC',
  tulipPot: '#81D4FA',
  tulipRim: '#4FC3F7',
  sakuraPotLight: '#D7CCC8',
  sakuraPot: '#BCAAA4',
  sakuraPetal: '#F8BBD0',
  rosePotLight: '#E8B4B8',
  rosePot: '#D4899A',
  roseRim: '#C07080',
  roseBloom: '#E57373',
  roseBud: '#EF5350',
  rosePetalLight: '#FFCDD2',
  sunflowerPotLight: '#A1887F',
  sunflowerCenter: '#9E9D24',
  sunflowerPetal: '#FFD54F',
  weatherLeaf: '#FFB74D',
  vinylEdge: '#1E1E1E',
  vinylCore: '#050505',
  vinylLabel: '#8E0E3A',
} as const;
