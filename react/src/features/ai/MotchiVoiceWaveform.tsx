// Port of lib/features/ai/presentation/widgets/motchi_voice_waveform.dart.
import { AppColors, Derived } from '../../core/theme/colors';
import { motionReduced } from '../../core/theme/motion';
import { lineHeight } from '../../core/theme/paint';
import { AppTypography } from '../../core/theme/typography';

export function MotchiVoiceWaveform({ levels }: { levels: number[] }) {
  const reduced = motionReduced();
  const active = levels.length > 0 && levels[levels.length - 1] > 0.03;
  const barColor = reduced && !active ? Derived.textMuted : AppColors.roseQuartz;

  return (
    <div style={{ padding: '4px 16px 8px', display: 'flex', alignItems: 'center', gap: 12 }}>
      <svg width={100} height={36} aria-hidden style={{ display: 'block', flexShrink: 0 }}>
        {levels.map((v, i) => {
          const step = 100 / levels.length;
          const clamped = Math.min(1, Math.max(0, v));
          const h = reduced ? 4 : 4 + clamped * 28;
          return <rect key={i} x={i * step} y={(36 - h) / 2} width={3} height={h} rx={2} ry={2} fill={barColor} />;
        })}
      </svg>
      <div role="status" aria-live="polite" style={{ flex: 1, minWidth: 0 }}>
        <div style={{ ...AppTypography.bodySmall, lineHeight: lineHeight(12.5), color: AppColors.roseQuartz }}>
          Listening · English
        </div>
        <div style={{ ...AppTypography.bodySmall, lineHeight: lineHeight(12.5) }}>Tap Stop to review</div>
      </div>
    </div>
  );
}
