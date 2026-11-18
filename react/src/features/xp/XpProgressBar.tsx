// Port of lib/features/xp/presentation/widgets/xp_progress_bar.dart.
import { useEffect, useRef, useState } from 'react';
import { AppColors, withAlpha } from '../../core/theme/colors';
import { AppRadius } from '../../core/theme/layout';
import { Align, letterSpacing, linear, shadowLayer } from '../../core/theme/paint';
import { AppTypography } from '../../core/theme/typography';
import { Icon } from '../../shared/widgets/Icon';
import { XP_PER_LEVEL, xpIntoLevel, xpToNextLevel, type UserProgress } from './xpService';

export function XpProgressBar({ progress }: { progress: UserProgress }) {
  const trackRef = useRef<HTMLDivElement>(null);
  const [trackWidth, setTrackWidth] = useState(300);

  useEffect(() => {
    const el = trackRef.current;
    if (!el) return;
    const update = () => setTrackWidth(el.clientWidth || 300);
    update();
    const ro = new ResizeObserver(update);
    ro.observe(el);
    return () => ro.disconnect();
  }, []);

  const currentLevelXp = xpIntoLevel(progress.xpTotal);
  const remaining = xpToNextLevel(progress.xpTotal);
  const pct = Math.max(0, Math.min(1, currentLevelXp / XP_PER_LEVEL));
  const fillW = trackWidth * pct;
  const thumbLeft = Math.max(0, Math.min(Math.max(0, trackWidth - 14), fillW - 7));

  const roseGold = linear([AppColors.auroraRose, AppColors.deepRose, AppColors.blushGold], {
    begin: Align.topLeft,
    end: Align.bottomRight,
    size: [Math.max(fillW, 110), 26],
  });

  return (
    <div style={{ position: 'relative' }}>
      <div
        style={shadowLayer(
          { color: withAlpha(AppColors.inkDeep, 0.45), blur: 20, offset: [0, 10] },
          { radius: AppRadius.xl },
        )}
        aria-hidden
      />
      <div
        style={shadowLayer(
          { color: withAlpha(AppColors.deepRose, 0.1), blur: 24, spread: -8 },
          { radius: AppRadius.xl },
        )}
        aria-hidden
      />
      <div
        style={{
          position: 'relative',
          overflow: 'hidden',
          padding: '14px 16px',
          borderRadius: AppRadius.xl,
          border: `1px solid ${withAlpha(AppColors.moonlight, 0.14)}`,
          background: linear([withAlpha(AppColors.velvet, 0.88), withAlpha(AppColors.inkDeep, 0.88)], {
            begin: Align.topLeft,
            end: Align.bottomRight,
            size: [500, 96],
          }),
        }}
      >
        <div style={{ position: 'relative' }}>
          <div
            style={{
              position: 'absolute',
              inset: 0,
              background: linear([withAlpha(AppColors.petalWhite, 0.05), AppColors.transparent], {
                begin: Align.topCenter,
                end: Align.bottomCenter,
              }),
              pointerEvents: 'none',
            }}
            aria-hidden
          />
          <div
            style={{
              position: 'absolute',
              top: 0,
              left: 14,
              right: 14,
              height: 1,
              background: linear([AppColors.transparent, withAlpha(AppColors.blushGold, 0.3), AppColors.transparent]),
              pointerEvents: 'none',
            }}
            aria-hidden
          />

          <div style={{ position: 'relative', display: 'flex', flexDirection: 'column', alignItems: 'stretch' }}>
          <div style={{ display: 'flex', alignItems: 'center' }}>
            <div style={{ position: 'relative' }}>
              <div
                style={shadowLayer({ color: withAlpha(AppColors.deepRose, 0.35), blur: 12 }, { radius: 999 })}
                aria-hidden
              />
              <div
                style={{
                  position: 'relative',
                  padding: '6px 10px',
                  borderRadius: 999,
                  background: roseGold,
                  display: 'inline-flex',
                  alignItems: 'center',
                }}
              >
                <Icon name="bolt" size={13} color={AppColors.petalWhite} />
                <div style={{ width: 6 }} />
                <span
                  style={{
                    ...AppTypography.outfitHeading,
                    color: AppColors.petalWhite,
                    fontSize: 11,
                    fontWeight: 800,
                    ...letterSpacing(1.6),
                  }}
                >
                  LEVEL {progress.level}
                </span>
              </div>
            </div>

            <div style={{ flex: 1 }} />

            <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'flex-end' }}>
              <span
                style={{
                  ...AppTypography.outfitHeading,
                  color: withAlpha(AppColors.petalWhite, 0.92),
                  fontSize: 12.5,
                  letterSpacing: 0.2,
                }}
              >
                {currentLevelXp} / {XP_PER_LEVEL} XP
              </span>
              <div style={{ height: 1 }} />
              <span
                style={{
                  ...AppTypography.outfitBold,
                  color: withAlpha(AppColors.blushGold, 0.72),
                  fontSize: 10,
                  letterSpacing: 0.6,
                }}
              >
                {remaining} XP to level {progress.level + 1}
              </span>
            </div>
          </div>

          <div style={{ height: 12 }} />

          <div
            ref={trackRef}
            style={{ position: 'relative', height: 14, display: 'flex', alignItems: 'center' }}
          >
            <div
              style={{
                width: '100%',
                height: 10,
                background: withAlpha(AppColors.moonlight, 0.08),
                borderRadius: 999,
                border: `1px solid ${withAlpha(AppColors.moonlight, 0.1)}`,
              }}
            />
            <div
              style={{
                position: 'absolute',
                left: 0,
                height: 10,
                width: fillW,
                borderRadius: 999,
                background: linear([AppColors.auroraRose, AppColors.deepRose, AppColors.blushGold], {
                  begin: Align.topLeft,
                  end: Align.bottomRight,
                  size: [Math.max(fillW, 1), 10],
                }),
                boxShadow: `0 0 12px ${withAlpha(AppColors.deepRose, 0.4)}, 0 0 16px ${withAlpha(AppColors.auroraGold, 0.25)}`,
                transition: 'width 900ms cubic-bezier(0.215, 0.61, 0.355, 1)',
              }}
            />
            <div
              style={{
                position: 'absolute',
                left: thumbLeft,
                width: 14,
                height: 14,
                borderRadius: '50%',
                background: linear([AppColors.petalWhite, AppColors.blushGold], {
                  begin: Align.topLeft,
                  end: Align.bottomRight,
                  size: [14, 14],
                }),
                border: `1px solid ${withAlpha(AppColors.petalWhite, 0.9)}`,
                boxShadow: `0 0 10px ${withAlpha(AppColors.auroraGold, 0.65)}, 0 0 14px ${withAlpha(AppColors.deepRose, 0.35)}`,
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
              }}
            >
              <div
                style={{
                  width: 6,
                  height: 6,
                  borderRadius: '50%',
                  background: withAlpha(AppColors.deepRose, 0.9),
                }}
              />
            </div>
          </div>
        </div>
        </div>
      </div>
    </div>
  );
}
