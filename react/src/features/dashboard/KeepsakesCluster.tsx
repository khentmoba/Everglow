// Port of lib/features/dashboard/presentation/widgets/keepsakes_cluster.dart.
import { useViewport } from '../../core/system/viewport';
import { AppColors, withAlpha } from '../../core/theme/colors';
import { AppRadius } from '../../core/theme/layout';
import { reduceAmbientMotion } from '../../core/theme/motion';
import { linear, radial, shadowLayer } from '../../core/theme/paint';
import { AppTypography } from '../../core/theme/typography';
import { BucketListPreview } from '../bucket_list/BucketListPreview';
import { JournalPreview } from './JournalPreview';

export function KeepsakesCluster() {
  const { width, height } = useViewport();
  const reduceAmbient = reduceAmbientMotion(width, height);
  const isWide = width >= 680;

  return (
    <div style={{ padding: '4px 16px', position: 'relative' }}>
      {!reduceAmbient && (
        <>
          <div style={shadowLayer({ color: withAlpha(AppColors.inkDeep, 0.28), blur: 24, offset: [0, 12] }, { radius: AppRadius.x3 })} aria-hidden />
          <div style={shadowLayer({ color: withAlpha(AppColors.blushGold, 0.07), blur: 18, spread: -6 }, { radius: AppRadius.x3 })} aria-hidden />
        </>
      )}
      <div
        style={{
          position: 'relative',
          overflow: 'hidden',
          background: withAlpha(AppColors.velvet, 0.32),
          borderRadius: AppRadius.x3,
          border: `1px solid ${withAlpha(AppColors.petalWhite, 0.08)}`,
        }}
      >
        {!reduceAmbient && (
          <>
            <div
              style={{
                position: 'absolute',
                top: -80,
                right: -50,
                width: 260,
                height: 260,
                borderRadius: '50%',
                background: radial([withAlpha(AppColors.blushGold, 0.1), AppColors.transparent], { size: [260, 260] }),
                pointerEvents: 'none',
              }}
            />
            <div
              style={{
                position: 'absolute',
                bottom: -80,
                left: -50,
                width: 260,
                height: 260,
                borderRadius: '50%',
                background: radial([withAlpha(AppColors.auroraLilac, 0.07), AppColors.transparent], { size: [260, 260] }),
                pointerEvents: 'none',
              }}
            />
          </>
        )}
        <div
          style={{
            position: 'absolute',
            top: 0,
            left: 24,
            right: 24,
            height: 1.2,
            background: linear([
              AppColors.transparent,
              withAlpha(AppColors.blushGold, 0.4),
              withAlpha(AppColors.auroraLilac, 0.3),
              AppColors.transparent,
            ]),
          }}
        />
        <div style={{ position: 'relative', padding: 18 }}>
          <div style={{ ...AppTypography.handwrittenBody, fontSize: 18, lineHeight: 1.1, color: withAlpha(AppColors.blushGold, 0.9) }}>
            keepsakes &amp; dreams
          </div>
          <div style={{ ...AppTypography.cormorantBold, fontSize: 22, color: AppColors.petalWhite, marginTop: 2 }}>
            Where your story lives
          </div>
          <div style={{ height: 16 }} />
          <div
            style={{
              display: 'flex',
              flexDirection: isWide ? 'row' : 'column',
              alignItems: 'stretch',
              gap: 14,
            }}
          >
            <div style={{ flex: 1, minWidth: 0 }}>
              <BucketListPreview />
            </div>
            <div style={{ flex: 1, minWidth: 0 }}>
              <JournalPreview />
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
