// Port of lib/features/watch_party/presentation/widgets/watch_party_card.dart.
import { useState } from 'react';
import { useNavigate } from 'react-router';
import { AppColors, Derived, withAlpha } from '../../core/theme/colors';
import { Align, boxShadow, linear, radial } from '../../core/theme/paint';
import { AppTypography } from '../../core/theme/typography';
import { Icon } from '../../shared/widgets/Icon';

const cWhite = AppColors.petalWhite;
const cDeepRose = AppColors.deepRose;
const cGold = AppColors.blushGold;
const cMuted = Derived.textMuted;

export function WatchPartyCard() {
  const navigate = useNavigate();
  const [hovered, setHovered] = useState(false);

  return (
    <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'stretch' }}>
      <WatchPartyHeader />
      <div style={{ height: 14 }} />
      <button
        type="button"
        className="bare-button"
        onMouseEnter={() => setHovered(true)}
        onMouseLeave={() => setHovered(false)}
        onClick={() => navigate('/watch-party')}
        style={{
          position: 'relative',
          display: 'block',
          width: '100%',
          textAlign: 'left',
          borderRadius: 20,
          overflow: 'hidden',
          background: linear(['#E63963', cDeepRose, '#8E1B3A'], {
            begin: Align.topLeft,
            end: Align.bottomRight,
          }),
          border: `1px solid ${withAlpha(AppColors.petalWhite, hovered ? 0.35 : 0.18)}`,
          boxShadow: boxShadow([
            { offset: [0, 10], blur: hovered ? 28 : 22, spread: -4, color: withAlpha(cDeepRose, hovered ? 0.52 : 0.38) },
            { offset: [0, 8], blur: 18, color: withAlpha('#000000', 0.25) },
          ]),
          transform: hovered ? 'translateY(-2px)' : 'none',
          transition: 'transform 200ms ease, box-shadow 200ms ease, border-color 200ms ease',
        }}
      >
        <div
          aria-hidden
          style={{
            position: 'absolute',
            top: -18,
            right: -10,
            width: 90,
            height: 90,
            borderRadius: '50%',
            background: radial([withAlpha(AppColors.petalWhite, 0.1), AppColors.transparent], { size: [90, 90] }),
            pointerEvents: 'none',
          }}
        />
        <div style={{ position: 'relative', padding: '16px 14px 14px 16px', display: 'flex', alignItems: 'center' }}>
          <div
            style={{
              position: 'relative',
              width: 58,
              height: 58,
              borderRadius: 16,
              background: linear([
                withAlpha(AppColors.petalWhite, 0.18),
                withAlpha(AppColors.petalWhite, 0.07),
              ]),
              border: `1px solid ${withAlpha(AppColors.petalWhite, 0.18)}`,
              boxShadow: boxShadow([{ blur: 10, color: withAlpha('#000000', 0.18) }]),
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              flexShrink: 0,
            }}
          >
            <div
              style={{
                position: 'absolute',
                width: 22,
                height: 22,
                borderRadius: '50%',
                background: withAlpha(AppColors.petalWhite, 0.14),
              }}
            />
            <Icon name="favorite" size={28} color={AppColors.petalWhite} />
            <div
              style={{
                position: 'absolute',
                right: 6,
                bottom: 6,
                width: 8,
                height: 8,
                borderRadius: '50%',
                background: '#FFE3EC',
                border: `1.2px solid ${AppColors.petalWhite}`,
                boxShadow: boxShadow([{ blur: 6, color: withAlpha(AppColors.petalWhite, 0.5) }]),
              }}
            />
          </div>

          <div style={{ width: 14, flexShrink: 0 }} />

          <div style={{ flex: 1, minWidth: 0 }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 7 }}>
              <span
                style={{
                  ...AppTypography.cormorantExtraBold,
                  fontSize: 18,
                  color: cWhite,
                  lineHeight: 1,
                  letterSpacing: '-0.2px',
                  whiteSpace: 'nowrap',
                  overflow: 'hidden',
                  textOverflow: 'ellipsis',
                }}
              >
                Open Watch Together
              </span>
              <span
                style={{
                  padding: '2px 6px',
                  background: withAlpha(AppColors.petalWhite, 0.14),
                  borderRadius: 999,
                  border: `1px solid ${withAlpha(AppColors.petalWhite, 0.22)}`,
                  display: 'inline-flex',
                  alignItems: 'center',
                  gap: 4,
                  flexShrink: 0,
                }}
              >
                <span style={{ width: 5, height: 5, borderRadius: '50%', background: '#FF6B8A' }} />
                <span
                  style={{
                    ...AppTypography.outfitWhite,
                    color: AppColors.petalWhite,
                    fontSize: 8,
                    fontWeight: 900,
                    letterSpacing: '1px',
                  }}
                >
                  LIVE
                </span>
              </span>
            </div>
            <div style={{ height: 4 }} />
            <div
              style={{
                ...AppTypography.outfitWhite,
                color: withAlpha(cWhite, 0.78),
                fontSize: 11.5,
                fontWeight: 500,
                lineHeight: 1.25,
              }}
            >
              Movie night in real time — press play together.
            </div>
            <div style={{ height: 8 }} />
            <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
              <div
                style={{
                  height: 1,
                  width: 18,
                  background: linear([withAlpha(AppColors.petalWhite, 0), withAlpha(AppColors.petalWhite, 0.35)]),
                }}
              />
              <span
                style={{
                  ...AppTypography.outfitWhite,
                  color: withAlpha(AppColors.petalWhite, 0.62),
                  fontSize: 8.5,
                  fontWeight: 700,
                  letterSpacing: '1.4px',
                }}
              >
                TAP TO ENTER THE ROOM
              </span>
            </div>
          </div>

          <div style={{ width: 10, flexShrink: 0 }} />

          <div
            style={{
              width: 40,
              height: 40,
              borderRadius: '50%',
              background: hovered ? AppColors.petalWhite : withAlpha(AppColors.petalWhite, 0.14),
              border: `1px solid ${withAlpha(AppColors.petalWhite, 0.22)}`,
              boxShadow: hovered ? boxShadow([{ blur: 12, color: withAlpha('#000000', 0.18) }]) : undefined,
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              flexShrink: 0,
              transition: 'background-color 200ms ease',
            }}
          >
            <Icon name="arrow_forward" size={20} color={hovered ? cDeepRose : AppColors.petalWhite} />
          </div>
        </div>
        <div
          aria-hidden
          style={{
            position: 'absolute',
            left: 16,
            right: 16,
            bottom: 0,
            height: 1,
            background: linear([AppColors.transparent, withAlpha(AppColors.petalWhite, 0.1), AppColors.transparent]),
          }}
        />
      </button>
    </div>
  );
}

function WatchPartyHeader() {
  return (
    <div style={{ display: 'flex', alignItems: 'center' }}>
      <div
        style={{
          width: 38,
          height: 38,
          borderRadius: 12,
          background: linear([cDeepRose, AppColors.rosePressed], {
            begin: Align.topLeft,
            end: Align.bottomRight,
          }),
          boxShadow: boxShadow([{ offset: [0, 3], blur: 10, color: withAlpha(cDeepRose, 0.35) }]),
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          flexShrink: 0,
        }}
      >
        <Icon name="favorite" size={20} color={AppColors.petalWhite} />
      </div>
      <div style={{ width: 12 }} />
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <span
            style={{
              ...AppTypography.cormorantBold,
              fontSize: 24,
              lineHeight: 1,
              letterSpacing: '0.2px',
              whiteSpace: 'nowrap',
              overflow: 'hidden',
              textOverflow: 'ellipsis',
            }}
          >
            Watch Together
          </span>
          <span
            style={{
              padding: '3px 8px',
              background: linear([withAlpha(cGold, 0.25), withAlpha(cGold, 0.1)]),
              borderRadius: 8,
              border: `1px solid ${withAlpha(cGold, 0.6)}`,
              display: 'inline-flex',
              alignItems: 'center',
              gap: 3,
              flexShrink: 0,
            }}
          >
            <Icon name="auto_awesome" size={10} color={cGold} />
            <span
              style={{
                ...AppTypography.outfitWhite,
                color: cGold,
                fontSize: 9,
                fontWeight: 800,
                letterSpacing: '1.2px',
              }}
            >
              NEW
            </span>
          </span>
        </div>
        <div style={{ height: 3 }} />
        <div
          style={{
            ...AppTypography.outfitHeading,
            color: cMuted,
            fontSize: 10,
            letterSpacing: '1.5px',
          }}
        >
          MOVIE NIGHT IN REAL TIME
        </div>
      </div>
    </div>
  );
}
