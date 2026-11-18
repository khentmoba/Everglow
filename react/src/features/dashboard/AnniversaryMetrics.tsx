// Port of lib/features/dashboard/presentation/widgets/anniversary_metrics.dart.
import { useEffect, useState } from 'react';
import { AppColors, withAlpha } from '../../core/theme/colors';
import { AppRadius } from '../../core/theme/layout';
import { Align, letterSpacing, linear, shadowLayer, insetBorder } from '../../core/theme/paint';
import { AppTypography } from '../../core/theme/typography';
import { EverglowSectionHeader } from '../../shared/widgets/EverglowSectionHeader';
import { Icon } from '../../shared/widgets/Icon';
import {
  ANNIVERSARY_DATE,
  calculateAnniversary,
  totalDaysSinceAnniversary,
  type AnniversaryCounter,
} from './anniversaryCounter';
import { MetricCard } from './MetricCard';

export function AnniversaryMetrics() {
  const [now, setNow] = useState(() => new Date());

  useEffect(() => {
    const id = window.setInterval(() => setNow(new Date()), 1000);
    return () => clearInterval(id);
  }, []);

  const counter = calculateAnniversary(ANNIVERSARY_DATE, now);
  const totalDays = totalDaysSinceAnniversary(now);

  return (
    <div style={{ padding: '20px 24px 0', display: 'flex', flexDirection: 'column', alignItems: 'stretch' }}>
      <SectionEyebrow counter={counter} />
      <div style={{ height: 14 }} />
      <div style={{ display: 'flex', justifyContent: 'center' }}>
        <div style={{ width: '100%', maxWidth: 560 }}>
          <KeepsakeClock counter={counter} totalDays={totalDays} />
        </div>
      </div>
    </div>
  );
}

function SectionEyebrow({ counter }: { counter: AnniversaryCounter }) {
  const tag =
    counter.years === 0
      ? counter.months === 1
        ? '1 month'
        : `${counter.months} months`
      : counter.years === 1
        ? '1 year'
        : `${counter.years} years`;

  return (
    <EverglowSectionHeader
      label="Time together"
      icon="favorite"
      hue={AppColors.auroraRose}
      trailing={
        <span style={{ ...AppTypography.handwrittenBody, fontSize: 18, lineHeight: 1, color: withAlpha(AppColors.blushGold, 0.9) }}>
          {tag}
        </span>
      }
    />
  );
}

function KeepsakeClock({ counter, totalDays }: { counter: AnniversaryCounter; totalDays: number }) {
  return (
    <div style={{ position: 'relative' }}>
      <div style={{ paddingBottom: 18, position: 'relative' }}>
        <div style={shadowLayer({ color: 'rgba(0,0,0,0.32)', blur: 30, offset: [0, 16] }, { radius: AppRadius.x3 })} aria-hidden />
        <div
          style={shadowLayer(
            { color: withAlpha(AppColors.auroraRose, 0.1), blur: 18, spread: -4, offset: [0, 4] },
            { radius: AppRadius.x3 },
          )}
          aria-hidden
        />
        <div
          style={{
            position: 'relative',
            overflow: 'hidden',
            borderRadius: AppRadius.x3,
            border: `1px solid ${withAlpha(AppColors.blushGold, 0.3)}`,
            background: linear(
              [
                withAlpha(AppColors.moonlight, 0.15),
                withAlpha(AppColors.velvet, 0.32),
                withAlpha(AppColors.inkDeep, 0.48),
                withAlpha(AppColors.plum, 0.24),
              ],
              { begin: Align.topLeft, end: Align.bottomRight, stops: [0, 0.3, 0.7, 1], size: [560, 440] },
            ),
          }}
        >
          <div
            style={{
              position: 'absolute',
              top: 0,
              left: 0,
              right: 0,
              height: 150,
              borderRadius: '28px 28px 0 0',
              background: linear(
                [withAlpha(AppColors.petalWhite, 0.12), withAlpha(AppColors.petalWhite, 0.02), AppColors.transparent],
                { begin: Align.topCenter, end: Align.bottomCenter, stops: [0, 0.45, 1] },
              ),
              pointerEvents: 'none',
            }}
          />
          <div style={{ position: 'absolute', left: -16, bottom: 60, pointerEvents: 'none' }} aria-hidden>
            <Icon name="favorite" size={78} color={withAlpha(AppColors.auroraRose, 0.04)} />
          </div>
          <div style={{ position: 'absolute', right: -14, top: -10, pointerEvents: 'none' }} aria-hidden>
            <Icon name="favorite" size={60} color={withAlpha(AppColors.blushGold, 0.04)} />
          </div>
          <div
            style={{
              position: 'absolute',
              top: 0,
              left: 32,
              right: 32,
              height: 1.2,
              background: linear(
                [
                  AppColors.transparent,
                  withAlpha(AppColors.blushGold, 0.4),
                  withAlpha(AppColors.petalWhite, 0.75),
                  withAlpha(AppColors.blushGold, 0.4),
                  AppColors.transparent,
                ],
                { stops: [0, 0.2, 0.5, 0.8, 1] },
              ),
            }}
          />

          <div style={{ position: 'relative', padding: '24px 20px 30px', display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
            <div style={{ position: 'relative' }}>
              <div
                style={shadowLayer(
                  { color: withAlpha(AppColors.auroraRose, 0.3), blur: 14, spread: -1 },
                  { circle: true },
                )}
                aria-hidden
              />
              <div
                style={{
                  position: 'relative',
                  width: 38,
                  height: 38,
                  borderRadius: '50%',
                  background: linear([withAlpha(AppColors.auroraRose, 0.28), withAlpha(AppColors.deepRose, 0.12)], {
                    begin: Align.topLeft,
                    end: Align.bottomRight,
                    size: [38, 38],
                  }),
                  ...insetBorder(withAlpha(AppColors.auroraRose, 0.5), 1.2),
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                }}
              >
                <Icon name="favorite" size={15} color={AppColors.auroraRose} />
              </div>
            </div>

            <div style={{ height: 10 }} />
            <span
              style={{
                ...AppTypography.outfitHeading,
                fontSize: 10.5,
                ...letterSpacing(2.4),
                fontWeight: 700,
                color: withAlpha(AppColors.blushGold, 0.95),
              }}
            >
              YEARS TOGETHER
            </span>
            <div style={{ height: 4 }} />
            <span
              style={{
                ...AppTypography.cormorantExtraBold,
                color: AppColors.auroraGold,
                fontSize: 66,
                lineHeight: 1,
                letterSpacing: -1,
                textShadow: `0 2px 12px ${withAlpha(AppColors.auroraGold, 0.45)}, 0 4px 6.3px ${withAlpha(AppColors.goldShadow, 0.35)}`,
              }}
            >
              {String(counter.years).padStart(2, '0')}
            </span>
            <div style={{ height: 10 }} />
            <DiamondDivider />
            <div style={{ height: 10 }} />
            <span
              style={{
                ...AppTypography.outfitWhite,
                fontSize: 12.5,
                letterSpacing: 0.4,
                fontWeight: 500,
                color: withAlpha(AppColors.petalWhite, 0.72),
              }}
            >
              since Feb 14, 2026
            </span>
            <div style={{ height: 18 }} />

            <div style={{ position: 'relative', alignSelf: 'stretch' }}>
              <div style={shadowLayer({ color: 'rgba(0,0,0,0.2)', blur: 16, offset: [0, 4] }, { radius: AppRadius.xl })} aria-hidden />
              <div
                style={{
                  position: 'relative',
                  overflow: 'hidden',
                  borderRadius: AppRadius.xl,
                  border: `1px solid ${withAlpha(AppColors.moonlight, 0.16)}`,
                  background: linear(
                    [withAlpha(AppColors.moonlight, 0.09), withAlpha(AppColors.inkDeep, 0.34), withAlpha(AppColors.velvet, 0.2)],
                    { begin: Align.topLeft, end: Align.bottomRight, stops: [0, 0.5, 1], size: [520, 221] },
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
                    background: linear([AppColors.transparent, withAlpha(AppColors.petalWhite, 0.25), AppColors.transparent]),
                  }}
                />
                <div style={{ height: 112, display: 'flex' }}>
                  <div style={{ flex: 1 }}>
                    <MetricCard label="Months" value={counter.months} flat />
                  </div>
                  <VDivider />
                  <div style={{ flex: 1 }}>
                    <MetricCard label="Days" value={counter.days} flat />
                  </div>
                </div>
                <HDivider />
                <div style={{ height: 108, display: 'flex' }}>
                  <div style={{ flex: 1 }}>
                    <MetricCard label="Hours" value={counter.hours} flat />
                  </div>
                  <VDivider />
                  <div style={{ flex: 1 }}>
                    <MetricCard label="Minutes" value={counter.minutes} flat />
                  </div>
                  <VDivider />
                  <div style={{ flex: 1 }}>
                    <MetricCard label="Seconds" value={counter.seconds} isLive flat />
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <div style={{ position: 'absolute', left: 24, right: 24, bottom: 0, display: 'flex', justifyContent: 'center' }}>
        <TotalDaysRibbon totalDays={totalDays} />
      </div>
    </div>
  );
}

function DiamondDivider() {
  return (
    <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
      <div style={{ width: 36, height: 1, background: linear([AppColors.transparent, withAlpha(AppColors.blushGold, 0.55)]) }} />
      <div style={{ margin: '0 8px' }}>
        <div
          style={{
            width: 5,
            height: 5,
            transform: 'rotate(45deg)',
            background: AppColors.auroraGold,
            boxShadow: `0 0 4px ${withAlpha(AppColors.auroraGold, 0.6)}`,
          }}
        />
      </div>
      <div style={{ width: 36, height: 1, background: linear([withAlpha(AppColors.blushGold, 0.55), AppColors.transparent]) }} />
    </div>
  );
}

function VDivider() {
  return (
    <div
      style={{
        width: 1,
        margin: '18px 0',
        background: linear(
          [AppColors.transparent, withAlpha(AppColors.moonlight, 0.2), withAlpha(AppColors.petalWhite, 0.12), AppColors.transparent],
          { begin: Align.topCenter, end: Align.bottomCenter, stops: [0, 0.4, 0.6, 1] },
        ),
      }}
    />
  );
}

function HDivider() {
  return (
    <div
      style={{
        height: 1,
        margin: '0 20px',
        background: linear(
          [AppColors.transparent, withAlpha(AppColors.moonlight, 0.2), withAlpha(AppColors.petalWhite, 0.12), AppColors.transparent],
          { stops: [0, 0.4, 0.6, 1] },
        ),
      }}
    />
  );
}

function TotalDaysRibbon({ totalDays }: { totalDays: number }) {
  return (
    <div style={{ position: 'relative' }}>
      <div style={shadowLayer({ color: 'rgba(0,0,0,0.32)', blur: 16, offset: [0, 6] }, { radius: 999 })} aria-hidden />
      <div
        style={shadowLayer(
          { color: withAlpha(AppColors.auroraRose, 0.15), blur: 14, spread: -2, offset: [0, 2] },
          { radius: 999 },
        )}
        aria-hidden
      />
      <div
        style={{
          position: 'relative',
          padding: '10px 18px',
          borderRadius: 999,
          border: `1px solid ${withAlpha(AppColors.blushGold, 0.35)}`,
          background: linear(
            [withAlpha(AppColors.moonlight, 0.16), withAlpha(AppColors.velvet, 0.62), withAlpha(AppColors.inkDeep, 0.72)],
            { begin: Align.topLeft, end: Align.bottomRight, size: [260, 36] },
          ),
        }}
      >
        <div
          style={{
            position: 'absolute',
            top: 0,
            left: 14,
            right: 14,
            height: 1,
            background: linear([AppColors.transparent, withAlpha(AppColors.petalWhite, 0.35), AppColors.transparent]),
          }}
        />
        <div style={{ display: 'inline-flex', alignItems: 'center' }}>
          <Icon name="favorite" size={11} color={AppColors.auroraRose} />
          <div style={{ width: 8 }} />
          <span style={{ ...AppTypography.outfitWhite, fontSize: 12, letterSpacing: 0.3, fontWeight: 600, color: AppColors.petalWhite }}>
            {totalDays} days of us
          </span>
          <span style={{ ...AppTypography.outfitWhite, fontSize: 12, letterSpacing: 0.3, fontWeight: 500, color: withAlpha(AppColors.petalWhite, 0.62) }}>
            &nbsp;&nbsp;·&nbsp;&nbsp;since Feb 14, 2026
          </span>
        </div>
      </div>
    </div>
  );
}
