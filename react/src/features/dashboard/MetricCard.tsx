// Port of lib/features/dashboard/presentation/widgets/metric_card.dart.
import { useViewport } from '../../core/system/viewport';
import { AppColors, withAlpha } from '../../core/theme/colors';
import { AppRadius } from '../../core/theme/layout';
import { motionReduced, orZero, reduceAmbientMotion } from '../../core/theme/motion';
import { Align, letterSpacing, linear, shadowLayer } from '../../core/theme/paint';
import { AppTypography } from '../../core/theme/typography';
import { AnimatedSwitcher } from '../../shared/widgets/AnimatedSwitcher';

export function MetricCard({
  label,
  value,
  isLive = false,
  flat = false,
}: {
  label: string;
  value: number;
  isLive?: boolean;
  flat?: boolean;
}) {
  const { width, height } = useViewport();
  const reduceAmbient = reduceAmbientMotion(width, height);
  const content = <MetricContent label={label} value={value} isLive={isLive} reduceAmbient={reduceAmbient} />;

  if (flat) {
    return <div style={{ padding: '14px 6px 12px', height: '100%', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>{content}</div>;
  }

  const borderColor = isLive ? withAlpha(AppColors.auroraRose, 0.35) : withAlpha(AppColors.moonlight, 0.16);
  return (
    <div style={{ position: 'relative' }}>
      {!reduceAmbient && (
        <>
          <div style={shadowLayer({ color: 'rgba(0,0,0,0.25)', blur: 18, offset: [0, 8] }, { radius: AppRadius.xl })} aria-hidden />
          {isLive && (
            <div style={shadowLayer({ color: withAlpha(AppColors.auroraRose, 0.16), blur: 20, offset: [0, 4] }, { radius: AppRadius.xl })} aria-hidden />
          )}
        </>
      )}
      <div
        style={{
          position: 'relative',
          overflow: 'hidden',
          borderRadius: AppRadius.xl,
          border: `1px solid ${borderColor}`,
          background: linear(
            [withAlpha(AppColors.moonlight, 0.12), withAlpha(AppColors.velvet, 0.32), withAlpha(AppColors.inkDeep, 0.45)],
            { begin: Align.topLeft, end: Align.bottomRight, size: [160, 110] },
          ),
        }}
      >
        <div
          style={{
            position: 'absolute',
            top: 0,
            left: 20,
            right: 20,
            height: 1,
            background: linear([AppColors.transparent, withAlpha(AppColors.blushGold, isLive ? 0.5 : 0.38), AppColors.transparent]),
          }}
        />
        <div style={{ padding: '16px 14px 14px' }}>{content}</div>
      </div>
    </div>
  );
}

function MetricContent({
  label,
  value,
  isLive,
  reduceAmbient,
}: {
  label: string;
  value: number;
  isLive: boolean;
  reduceAmbient: boolean;
}) {
  const dur = reduceAmbient || motionReduced() ? 0 : orZero(300);
  const padded = String(value).padStart(2, '0');
  return (
    <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center' }}>
      <AnimatedSwitcher id={padded} duration={dur}>
        <span
          style={{
            ...AppTypography.cormorantExtraBold,
            color: AppColors.auroraGold,
            fontSize: 38,
            lineHeight: 1,
            letterSpacing: -0.5,
            textShadow: `0 1px 8.6px ${withAlpha(AppColors.auroraGold, 0.42)}, 0 2px 5.1px ${withAlpha(AppColors.goldShadow, 0.3)}`,
          }}
        >
          {padded}
        </span>
      </AnimatedSwitcher>
      <div style={{ height: 9 }} />
      <div
        style={{
          width: 22,
          height: 1,
          background: linear([AppColors.transparent, withAlpha(AppColors.blushGold, 0.48), AppColors.transparent]),
        }}
      />
      <div style={{ height: 9 }} />
      <div style={{ display: 'inline-flex', alignItems: 'center', justifyContent: 'center' }}>
        {isLive && (
          <>
            <div
              style={{
                width: 5,
                height: 5,
                borderRadius: '50%',
                background: AppColors.auroraRose,
                boxShadow: `0 0 4px 1px ${withAlpha(AppColors.auroraRose, 0.7)}`,
              }}
            />
            <div style={{ width: 6 }} />
          </>
        )}
        <span
          style={{
            ...AppTypography.outfitHeading,
            color: withAlpha(AppColors.roseQuartz, 0.85),
            fontSize: 9.5,
            ...letterSpacing(2.0),
            fontWeight: 700,
            textAlign: 'center',
          }}
        >
          {label.toUpperCase()}
        </span>
      </div>
    </div>
  );
}
