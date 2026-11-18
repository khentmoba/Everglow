// Port of lib/features/play_zone/presentation/screens/play_zone_hub_screen.dart.
import type { ReactNode } from 'react';
import { useNavigate } from 'react-router';
import { useBoxSize } from '../../core/system/useBoxSize';
import { useViewport } from '../../core/system/viewport';
import { AppColors, withAlpha } from '../../core/theme/colors';
import { AppRadius, AppSpacing } from '../../core/theme/layout';
import { Align, letterSpacing, linear, lineHeight, shadowLayer, type BoxShadow } from '../../core/theme/paint';
import { AppTypography } from '../../core/theme/typography';
import { EverglowBackground } from '../../shared/widgets/EverglowBackground';
import { EverglowButton } from '../../shared/widgets/EverglowButton';
import { EverglowFeatureHeader } from '../../shared/widgets/EverglowFeatureHeader';
import { EverglowSectionHeader } from '../../shared/widgets/EverglowSectionHeader';
import { Icon } from '../../shared/widgets/Icon';

export function PlayZoneHubPage() {
  const navigate = useNavigate();
  const { width } = useViewport();
  const pageH = AppSpacing.pageH(width);

  return (
    <div style={{ position: 'fixed', inset: 0, display: 'flex', flexDirection: 'column' }}>
      <EverglowBackground
        baseColor={AppColors.inkDeep}
        glows={[
          { color: AppColors.auroraGold, alignment: [0.8, -0.85], size: 0.85, opacity: 0.12 },
          { color: AppColors.deepRose, alignment: [-0.85, 0.2], size: 0.75, opacity: 0.12 },
          { color: AppColors.auroraTeal, alignment: [0.85, 0.9], size: 0.7, opacity: 0.1 },
        ]}
      />
      <div style={{ position: 'relative', display: 'flex', flexDirection: 'column', height: '100%' }}>
        <EverglowFeatureHeader
          title="Play Zone"
          subtitle="arcade · co-op · games for two"
          icon="sports_esports"
          hue={AppColors.auroraGold}
        />
        <div className="no-scrollbar" style={{ flex: 1, minHeight: 0, overflowY: 'auto' }}>
          <div style={{ padding: `${AppSpacing.md}px ${pageH}px ${AppSpacing.x3}px` }}>
            <div style={{ maxWidth: 620, margin: '0 auto', display: 'flex', flexDirection: 'column' }}>
              <WelcomeHero />
              <div style={{ height: AppSpacing.xl }} />
              <EverglowSectionHeader label="Choose your arena" icon="videogame_asset" hue={AppColors.auroraRose} />
              <div style={{ height: AppSpacing.md }} />
              <PlayZoneGameCard
                title="Table Tennis World Tour"
                subtitle="Smash through the international tournament bracket solo, or rally face-to-face against Clair in a fast real-time 1v1 showdown!"
                badge="ARCADE · FAST 60 FPS"
                icon="sports_tennis"
                accent={AppColors.warmAmber}
                tags={['1v1 Matchmaking', 'Solo Tournament', 'Smooth Physics']}
                actions={[
                  <EverglowButton
                    key="solo"
                    label="Solo Tournament"
                    icon="sports_tennis"
                    backgroundColor={AppColors.warmAmber}
                    foregroundColor={AppColors.inkDeep}
                    onPressed={() => navigate('/play-zone/tt')}
                  />,
                  <EverglowButton
                    key="1v1"
                    variant="glass"
                    label="1v1 Match"
                    icon="people"
                    foregroundColor={AppColors.blushGold}
                    onPressed={() => navigate('/play-zone/tt/lobby')}
                  />,
                ]}
              />
              <div style={{ height: AppSpacing.lg }} />
              <PlayZoneGameCard
                title="Scribble Together"
                subtitle="One draws, one guesses! Real-time synchronized canvas with live strokes, instant word reveals, and playful inside jokes."
                badge="CO-OP · DRAW & GUESS"
                icon="brush"
                accent={AppColors.auroraTeal}
                tags={['Live Canvas', 'Couple Guessing', 'Instant Sync']}
                actions={[
                  <EverglowButton
                    key="draw"
                    label="Start Drawing"
                    icon="brush"
                    backgroundColor={AppColors.auroraTeal}
                    foregroundColor={AppColors.inkDeep}
                    onPressed={() => navigate('/play-zone/scribble')}
                  />,
                ]}
              />
              <div style={{ height: AppSpacing.lg }} />
              <PlayZoneGameCard
                title="Couple Chess"
                subtitle="Our private board with full chess rules, checkmate detection, move history, and quiet cozy turns together."
                badge="CLASSIC · PASS & PLAY"
                icon="grid_4x4"
                accent={AppColors.auroraRose}
                tags={['2-Player Board', 'Move History', 'No Rush']}
                actions={[
                  <EverglowButton
                    key="chess"
                    label="Play Chess"
                    icon="grid_view"
                    backgroundColor={AppColors.deepRose}
                    foregroundColor={AppColors.petalWhite}
                    onPressed={() => navigate('/play-zone/chess')}
                  />,
                ]}
              />
              <div style={{ height: AppSpacing.lg }} />
              <PlayZoneGameCard
                title="Motchi's Minis"
                subtitle="Tiny games Motchi built just for you two — saved from chat, ready to replay anytime."
                badge="MOTCHI MADE · SAVED GAMES"
                icon="sports_esports"
                accent={AppColors.auroraLilac}
                tags={['Made For Two', 'Replay Anytime', 'From Chat']}
                actions={[
                  <EverglowButton
                    key="minis"
                    label="Open Minis"
                    icon="play_circle_fill"
                    backgroundColor={AppColors.auroraLilac}
                    foregroundColor={AppColors.inkDeep}
                    onPressed={() => navigate('/motchi-minis')}
                  />,
                ]}
              />
              <div style={{ height: AppSpacing.x2 }} />
              <div style={{ padding: `${AppSpacing.sm}px 0`, display: 'flex', justifyContent: 'center', alignItems: 'center' }}>
                <Icon name="favorite" size={14} color={withAlpha(AppColors.auroraRose, 0.85)} />
                <div style={{ width: AppSpacing.sm }} />
                <span
                  style={{
                    ...AppTypography.outfitWhite,
                    fontSize: 12,
                    ...letterSpacing(0.25),
                    color: withAlpha(AppColors.roseQuartz, 0.72),
                  }}
                >
                  More mini-games coming soon — made with love for Clair
                </span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

function WelcomeHero() {
  const [ref, size] = useBoxSize<HTMLDivElement>();
  return (
    <UnderShadow shadow={{ color: withAlpha(AppColors.auroraGold, 0.08), blur: 24, offset: [0, 8] }}>
      <div
        ref={ref}
        style={{
          padding: AppSpacing.xl,
          background: linear([withAlpha(AppColors.velvet, 0.9), withAlpha(AppColors.inkDeep, 0.95)], {
            begin: Align.topLeft,
            end: Align.bottomRight,
            size,
          }),
          borderRadius: AppRadius.x2,
          border: `1px solid ${withAlpha(AppColors.blushGold, 0.22)}`,
        }}
      >
        <div style={{ display: 'flex', alignItems: 'center' }}>
          <div
            style={{
              padding: AppSpacing.sm,
              background: withAlpha(AppColors.auroraGold, 0.15),
              borderRadius: AppRadius.sm,
              border: `1px solid ${withAlpha(AppColors.auroraGold, 0.35)}`,
              display: 'flex',
            }}
          >
            <Icon name="sports_esports" size={20} color={AppColors.auroraGold} />
          </div>
          <div style={{ width: AppSpacing.md }} />
          <span
            style={{
              flex: 1,
              minWidth: 0,
              ...AppTypography.cormorantBold,
              fontSize: 24,
              lineHeight: lineHeight(24, 1.15),
              color: AppColors.roseQuartz,
            }}
          >
            Ready for Game Night?
          </span>
        </div>
        <div style={{ height: AppSpacing.sm }} />
        <span
          style={{
            display: 'block',
            ...AppTypography.outfitWhite,
            fontSize: 13.5,
            lineHeight: lineHeight(13.5, 1.45),
            ...letterSpacing(0.25),
            color: withAlpha(AppColors.petalWhite, 0.82),
          }}
        >
          Playful showdowns, shared live drawings, and cozy board games made just for Khent &amp; Clair.
        </span>
        <div style={{ height: AppSpacing.md }} />
        <div style={{ display: 'flex', flexWrap: 'wrap', gap: `${AppSpacing.xs}px ${AppSpacing.sm}px` }}>
          <HeroPill icon="people_outline" label="Couples Only" hue={AppColors.roseQuartz} />
          <HeroPill icon="bolt" label="Instant Sync" hue={AppColors.auroraGold} />
          <HeroPill icon="favorite_border" label="No Ads · Pure Us" hue={AppColors.auroraRose} />
        </div>
      </div>
    </UnderShadow>
  );
}

/** Flutter paints a BoxShadow under the whole box, so it shows through see-through fills. */
function UnderShadow({ shadow, children }: { shadow: BoxShadow; children: ReactNode }) {
  return (
    <div style={{ position: 'relative' }}>
      <div aria-hidden style={shadowLayer(shadow, { radius: AppRadius.x2 })} />
      <div style={{ position: 'relative' }}>{children}</div>
    </div>
  );
}

function HeroPill({ icon, label, hue }: { icon: string; label: string; hue: string }) {
  return (
    <div
      style={{
        padding: `3px ${AppSpacing.sm}px`,
        background: withAlpha(hue, 0.12),
        borderRadius: AppRadius.full,
        border: `1px solid ${withAlpha(hue, 0.28)}`,
        display: 'inline-flex',
        alignItems: 'center',
      }}
    >
      <Icon name={icon} size={12} color={hue} />
      <div style={{ width: AppSpacing.xs }} />
      <span style={{ ...AppTypography.outfitHeading, fontSize: 10, ...letterSpacing(0.5), fontWeight: 600, color: hue }}>
        {label}
      </span>
    </div>
  );
}

function PlayZoneGameCard({
  title,
  subtitle,
  badge,
  icon,
  accent,
  tags,
  actions,
}: {
  title: string;
  subtitle: string;
  badge: string;
  icon: string;
  accent: string;
  tags: string[];
  actions: ReactNode[];
}) {
  return (
    <UnderShadow shadow={{ color: withAlpha(accent, 0.08), blur: 20, offset: [0, 4] }}>
      <div
        role="group"
        aria-label={title}
        style={{
          padding: AppSpacing.xl,
          background: withAlpha(AppColors.velvet, 0.72),
          borderRadius: AppRadius.x2,
          border: `1px solid ${withAlpha(AppColors.moonlight, 0.08)}`,
        }}
      >
        <div style={{ display: 'flex', alignItems: 'center' }}>
          <div style={{ position: 'relative', width: 52, height: 52, flexShrink: 0 }}>
            <div
              aria-hidden
              style={shadowLayer({ color: withAlpha(accent, 0.22), blur: 10, offset: [0, 2] }, { radius: AppRadius.lg })}
            />
            <div
              style={{
                position: 'relative',
                width: 52,
                height: 52,
                background: withAlpha(accent, 0.14),
                borderRadius: AppRadius.lg,
                boxShadow: `inset 0 0 0 1.5px ${withAlpha(accent, 0.38)}`,
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
              }}
            >
              <Icon name={icon} size={26} color={accent} />
            </div>
          </div>
          <div style={{ width: AppSpacing.md }} />
          <div style={{ flex: 1, minWidth: 0, display: 'flex', flexDirection: 'column', alignItems: 'flex-start' }}>
            <div
              style={{
                maxWidth: '100%',
                boxSizing: 'border-box',
                padding: `2px ${AppSpacing.sm}px`,
                background: withAlpha(accent, 0.14),
                borderRadius: AppRadius.full,
                border: `1px solid ${withAlpha(accent, 0.35)}`,
              }}
            >
              <span
                className="ellipsis"
                style={{
                  display: 'block',
                  ...AppTypography.outfitHeading,
                  fontSize: 9.5,
                  ...letterSpacing(1.2),
                  fontWeight: 700,
                  color: accent,
                }}
              >
                {badge}
              </span>
            </div>
            <div style={{ height: AppSpacing.xs }} />
            <span
              className="clamp-2"
              style={{
                ...AppTypography.cormorantBold,
                fontSize: 22,
                lineHeight: lineHeight(22, 1.15),
                color: AppColors.petalWhite,
                ...letterSpacing(0.3),
              }}
            >
              {title}
            </span>
          </div>
        </div>
        <div style={{ height: AppSpacing.md }} />
        <span
          style={{
            display: 'block',
            ...AppTypography.outfitWhite,
            fontSize: 13,
            lineHeight: lineHeight(13, 1.45),
            ...letterSpacing(0.25),
            color: withAlpha(AppColors.petalWhite, 0.8),
          }}
        >
          {subtitle}
        </span>
        {tags.length > 0 && (
          <>
            <div style={{ height: AppSpacing.md }} />
            <div style={{ display: 'flex', flexWrap: 'wrap', gap: AppSpacing.xs }}>
              {tags.map((tag) => (
                <div
                  key={tag}
                  style={{
                    padding: `3px ${AppSpacing.sm}px`,
                    background: withAlpha(AppColors.moonlight, 0.05),
                    borderRadius: AppRadius.xs,
                    border: `1px solid ${withAlpha(AppColors.moonlight, 0.1)}`,
                  }}
                >
                  <span
                    style={{
                      display: 'block',
                      ...AppTypography.outfitWhite,
                      fontSize: 11,
                      ...letterSpacing(0.25),
                      color: withAlpha(AppColors.roseQuartz, 0.85),
                    }}
                  >
                    {tag}
                  </span>
                </div>
              ))}
            </div>
          </>
        )}
        {actions.length > 0 && (
          <>
            <div style={{ height: AppSpacing.lg }} />
            <div
              style={{ display: 'flex', flexWrap: 'wrap', alignItems: 'center', gap: `${AppSpacing.sm}px ${AppSpacing.md}px` }}
            >
              {actions}
            </div>
          </>
        )}
      </div>
    </UnderShadow>
  );
}
