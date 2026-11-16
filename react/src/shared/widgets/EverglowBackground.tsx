// Port of lib/shared/widgets/everglow/everglow_background.dart (glows only;
// the drifting-petal option moves over with the first screen that uses it).
import { useViewport } from '../../core/system/viewport';
import { AppColors, withAlpha } from '../../core/theme/colors';
import type { Alignment } from '../../core/theme/paint';

export type RadialGlow = { color: string; alignment: Alignment; size?: number; opacity?: number };

export const defaultGlows: RadialGlow[] = [
  { color: AppColors.deepRose, alignment: [-0.7, -0.85], size: 0.8, opacity: 0.06 },
  { color: AppColors.softLavender, alignment: [0.85, 0.95], size: 0.7, opacity: 0.06 },
];

export function EverglowBackground({
  baseColor = AppColors.twilight,
  glows = defaultGlows,
}: {
  baseColor?: string;
  glows?: RadialGlow[];
}) {
  const { width, height } = useViewport();
  return (
    <div style={{ position: 'absolute', inset: 0, background: baseColor, pointerEvents: 'none', overflow: 'hidden' }} aria-hidden>
      {glows.map((g, i) => {
        const r = (g.size ?? 0.8) * Math.min(width, height);
        const cx = ((g.alignment[0] + 1) / 2) * width;
        const cy = ((g.alignment[1] + 1) / 2) * height;
        return (
          <div
            key={i}
            style={{
              position: 'absolute',
              left: cx - r,
              top: cy - r,
              width: r * 2,
              height: r * 2,
              background: `radial-gradient(circle ${r}px at 50% 50%, ${withAlpha(g.color, g.opacity ?? 0.15)}, ${withAlpha(g.color, 0)})`,
            }}
          />
        );
      })}
    </div>
  );
}
