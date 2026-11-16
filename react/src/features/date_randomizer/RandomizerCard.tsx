// Port of lib/features/date_randomizer/presentation/widgets/randomizer_card.dart.
import { useState } from 'react';
import { AgentFixtures } from '../../core/agent/fixtures';
import { AppColors, withAlpha } from '../../core/theme/colors';
import { AppRadius } from '../../core/theme/layout';
import { Align, letterSpacing, linear, shadowLayer } from '../../core/theme/paint';
import { AppTypography } from '../../core/theme/typography';
import { Icon } from '../../shared/widgets/Icon';

export function RandomizerCard() {
  const [useAI, setUseAI] = useState(false);
  const [spinning, setSpinning] = useState(false);
  const [picked, setPicked] = useState<string | null>(null);

  const handleSpin = () => {
    if (spinning) return;
    setSpinning(true);
    window.setTimeout(() => {
      const ideas = AgentFixtures.demoDateIdeas();
      const chosen = ideas[Math.floor(Math.random() * ideas.length)];
      setSpinning(false);
      setPicked(chosen.title);
    }, 1800);
  };

  return (
    <div style={{ padding: '0 24px', position: 'relative' }}>
      <div style={shadowLayer({ color: withAlpha(AppColors.inkDeep, 0.45), blur: 20, offset: [0, 8] }, { radius: AppRadius.x2 })} aria-hidden />
      <div style={shadowLayer({ color: withAlpha(AppColors.deepRose, 0.12), blur: 26, spread: -6 }, { radius: AppRadius.x2 })} aria-hidden />
      <div
        style={{
          position: 'relative',
          padding: 28,
          borderRadius: AppRadius.x2,
          border: `1px solid ${withAlpha(AppColors.moonlight, 0.14)}`,
          background: linear([withAlpha(AppColors.velvet, 0.52), withAlpha(AppColors.inkDeep, 0.58)], {
            begin: Align.topLeft,
            end: Align.bottomRight,
          }),
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
        }}
      >
        <div
          style={{
            position: 'absolute',
            top: 0,
            left: 22,
            right: 22,
            height: 1.4,
            background: linear([AppColors.transparent, withAlpha(AppColors.auroraGold, 0.55), AppColors.transparent]),
          }}
        />
        <span style={{ ...AppTypography.cormorantBlack, fontSize: 26, letterSpacing: 1 }}>Digital Roulette</span>
        <div style={{ height: 6 }} />
        <span
          style={{
            ...AppTypography.outfitWhite,
            color: withAlpha(AppColors.petalWhite, 0.75),
            fontSize: 12,
            fontWeight: 700,
            ...letterSpacing(1.6),
          }}
        >
          SPIN FOR A DATE DESTINY
        </span>
        <div style={{ height: 16 }} />

        <button
          type="button"
          className="bare-button"
          onClick={() => setUseAI((v) => !v)}
          style={{
            padding: '7px 14px',
            borderRadius: 20,
            background: useAI ? withAlpha(AppColors.auroraGold, 0.18) : withAlpha(AppColors.moonlight, 0.08),
            border: `1px solid ${useAI ? withAlpha(AppColors.auroraGold, 0.7) : withAlpha(AppColors.moonlight, 0.22)}`,
            display: 'inline-flex',
            alignItems: 'center',
            gap: 6,
          }}
        >
          <Icon name={useAI ? 'auto_awesome' : 'shuffle'} size={14} color={useAI ? AppColors.auroraGold : withAlpha(AppColors.petalWhite, 0.7)} />
          <span style={{ ...AppTypography.outfitBold, fontSize: 11, color: useAI ? AppColors.auroraGold : withAlpha(AppColors.petalWhite, 0.7) }}>
            {useAI ? 'AI Powered' : 'Random'}
          </span>
        </button>

        <div style={{ height: 36 }} />

        <div style={{ position: 'relative', width: 156, height: 156, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
          <div
            style={{
              position: 'absolute',
              inset: 0,
              borderRadius: '50%',
              background: `conic-gradient(${AppColors.deepRose}, ${AppColors.auroraGold}, ${AppColors.softLavender}, ${AppColors.deepRose})`,
              boxShadow: `0 0 14px ${withAlpha(AppColors.deepRose, 0.35)}`,
              padding: 4,
              transform: spinning ? 'rotate(720deg)' : 'rotate(0deg)',
              transition: spinning ? 'transform 1.8s cubic-bezier(0.22, 1, 0.36, 1)' : undefined,
            }}
          >
            <div style={{ width: '100%', height: '100%', borderRadius: '50%', background: AppColors.inkDeep }} />
          </div>
          <button
            type="button"
            className="bare-button"
            aria-label="Spin date roulette"
            onClick={handleSpin}
            style={{
              position: 'relative',
              width: 72,
              height: 72,
              borderRadius: '50%',
              background: linear([AppColors.deepRose, AppColors.auroraRose]),
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              boxShadow: `0 4px 16px ${withAlpha(AppColors.deepRose, 0.45)}`,
            }}
          >
            <Icon name="favorite" size={30} color={AppColors.petalWhite} />
          </button>
        </div>
      </div>

      {picked && (
        <div
          onClick={() => setPicked(null)}
          style={{
            position: 'fixed',
            inset: 0,
            background: withAlpha(AppColors.deepRose, 0.3),
            zIndex: 1100,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            padding: 20,
          }}
        >
          <div
            onClick={(e) => e.stopPropagation()}
            style={{
              width: '100%',
              maxWidth: 380,
              padding: 28,
              borderRadius: 28,
              background: linear([AppColors.velvet, AppColors.inkDeep]),
              border: `1.5px solid ${withAlpha(AppColors.auroraGold, 0.5)}`,
              textAlign: 'center',
            }}
          >
            <div style={{ fontSize: 32 }}>🎉</div>
            <div style={{ ...AppTypography.cormorantBold, fontSize: 24, color: AppColors.auroraGold, marginTop: 8 }}>
              Tonight&rsquo;s Date Destiny
            </div>
            <div style={{ ...AppTypography.outfitBold, fontSize: 16, color: AppColors.petalWhite, marginTop: 12 }}>
              {picked}
            </div>
            <button
              type="button"
              className="bare-button"
              onClick={() => setPicked(null)}
              style={{
                margin: '18px auto 0',
                padding: '10px 22px',
                borderRadius: 999,
                background: AppColors.deepRose,
                ...AppTypography.outfitBold,
                fontSize: 13,
              }}
            >
              Let&rsquo;s do it! 💖
            </button>
          </div>
        </div>
      )}
    </div>
  );
}
