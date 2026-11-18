// Port of lib/features/ai/presentation/screens/motchi_minis_screen.dart.
import { useState } from 'react';
import { useNavigate } from 'react-router';
import { AppColors, Derived, withAlpha } from '../../core/theme/colors';
import { AppRadius } from '../../core/theme/layout';
import { Align, boxShadow, linear, lineHeight } from '../../core/theme/paint';
import { AppTypography } from '../../core/theme/typography';
import { AlertDialog, showDialog, TextButton } from '../../shared/widgets/Dialogs';
import { EverglowBackground } from '../../shared/widgets/EverglowBackground';
import { EverglowFeatureHeader } from '../../shared/widgets/EverglowFeatureHeader';
import { EverglowEmptyState, EverglowSkeleton, EverglowStreamView } from '../../shared/widgets/EverglowStates';
import { Icon } from '../../shared/widgets/Icon';
import { showSnackBar } from '../../shared/widgets/SnackBar';
import { MaterialIconButton } from '../../shared/widgets/MaterialFields';
import { canPop } from '../../shared/widgets/MaterialFields';
import { openCanvasPreview } from './CanvasPreviewSheet';
import { motchiMinisService, type MiniGame } from './motchiMinisService';

const savedBy = (username: string) => (username === 'khentsgdz' ? 'Dada' : username === 'clairjassen' ? 'Mama' : 'Motchi');
const savedOn = (date: Date | null) =>
  date == null ? 'just now' : date.toLocaleDateString('en-US', { month: 'short', day: 'numeric' });

async function remove(game: MiniGame) {
  const confirmed = await showDialog<boolean>((close) => (
    <AlertDialog
      background={AppColors.velvet}
      radius={AppRadius.lg}
      title={<span style={{ ...AppTypography.titleMedium, lineHeight: lineHeight(16, 1.5) }}>Remove this game?</span>}
      content={
        <span style={{ ...AppTypography.bodyMedium, lineHeight: lineHeight(14) }}>
          "{game.title}" will leave the shelf. Motchi can always build it again.
        </span>
      }
      actions={[
        <TextButton key="keep" onPressed={() => close(false)}>
          <span style={{ ...AppTypography.bodyMedium, color: Derived.textMuted }}>Keep</span>
        </TextButton>,
        <TextButton key="remove" onPressed={() => close(true)}>
          <span style={{ ...AppTypography.bodyMedium, color: AppColors.auroraRose, fontWeight: 700 }}>Remove</span>
        </TextButton>,
      ]}
    />
  ));
  if (confirmed !== true) return;
  await motchiMinisService.deleteMini(game.id);
  showSnackBar('Removed from the shelf', { background: AppColors.velvet, duration: 2000 });
}

export function MotchiMinisPage() {
  const navigate = useNavigate();
  const [retry, setRetry] = useState(0);
  return (
    <div style={{ position: 'fixed', inset: 0, background: AppColors.inkDeep }}>
      <EverglowBackground
        baseColor={AppColors.inkDeep}
        glows={[
          { color: AppColors.auroraLilac, alignment: [-0.7, -0.9], size: 0.9, opacity: 0.14 },
          { color: AppColors.deepRose, alignment: [0.9, 0.9], size: 0.8, opacity: 0.1 },
        ]}
      />
      <div
        style={{
          position: 'absolute',
          inset: 0,
          paddingTop: 'env(safe-area-inset-top)',
          paddingBottom: 'env(safe-area-inset-bottom)',
          display: 'flex',
          flexDirection: 'column',
        }}
      >
        <EverglowFeatureHeader
          title="Motchi's Minis"
          subtitle="saved games · made for you two"
          icon="sports_esports"
          hue={AppColors.auroraRose}
          onBack={() => (canPop() ? navigate(-1) : navigate('/motchi'))}
        />
        <div style={{ flex: 1, minHeight: 0, display: 'flex', flexDirection: 'column' }}>
          <EverglowStreamView
            source={() => motchiMinisService.watchMinis()}
            sourceKey={[retry]}
            label="motchi-minis"
            errorMessage="Could not load saved games"
            errorIcon="sports_esports_outlined"
            onRetry={() => setRetry((r) => r + 1)}
            loadingView={
              <div style={{ padding: '4px 16px 20px', display: 'flex', flexDirection: 'column', gap: 12 }}>
                <EverglowSkeleton height={84} radius={20} />
                <EverglowSkeleton height={84} radius={20} />
              </div>
            }
            isEmpty={(games) => games.length === 0}
            emptyView={
              <div style={{ height: '100%', display: 'flex', flexDirection: 'column' }}>
                <EverglowEmptyState
                  icon="sports_esports"
                  title="No saved games yet"
                  subtitle="Ask Motchi to build you a game, then tap Save in the preview 🍡"
                  ctaLabel="Ask Motchi"
                  onCta={() => navigate('/motchi')}
                />
              </div>
            }
            builder={(games) => (
              <div className="no-scrollbar" style={{ height: '100%', overflowY: 'auto' }}>
                <div style={{ padding: '4px 16px 24px', display: 'flex', flexDirection: 'column', gap: 12 }}>
                  {games.map((game) => (
                    <MiniTile
                      key={game.id}
                      game={game}
                      subtitle={`${savedBy(game.createdBy)} · ${savedOn(game.createdAt)}`}
                      onPlay={() => void openCanvasPreview({ title: game.title, html: game.html })}
                      onDelete={() => void remove(game)}
                    />
                  ))}
                </div>
              </div>
            )}
          />
        </div>
      </div>
    </div>
  );
}

function MiniTile({
  game,
  subtitle,
  onPlay,
  onDelete,
}: {
  game: MiniGame;
  subtitle: string;
  onPlay: () => void;
  onDelete: () => void;
}) {
  const [hovered, setHovered] = useState(false);
  return (
    <div
      role="button"
      tabIndex={0}
      onClick={onPlay}
      onKeyDown={(e) => (e.key === 'Enter' || e.key === ' ') && onPlay()}
      onMouseEnter={() => setHovered(true)}
      onMouseLeave={() => setHovered(false)}
      style={{
        position: 'relative',
        padding: '13.1px 15.1px',
        display: 'flex',
        alignItems: 'center',
        background: withAlpha(AppColors.inkDeep, 0.88),
        borderRadius: AppRadius.xl,
        boxShadow: `inset 0 0 0 1.1px ${withAlpha(AppColors.auroraRose, 0.22)}, ${boxShadow([{ color: 'rgba(0,0,0,0.3)', blur: 14, offset: [0, 4] }])}`,
        cursor: 'pointer',
      }}
    >
      {hovered && (
        <div
          aria-hidden
          style={{
            position: 'absolute',
            inset: 0,
            borderRadius: AppRadius.xl,
            background: withAlpha(AppColors.petalWhite, 0.04),
          }}
        />
      )}
      <div
        style={{
          width: 46,
          height: 46,
          flexShrink: 0,
          borderRadius: 14,
          background: linear([AppColors.auroraRose, AppColors.auroraGold], {
            begin: Align.topLeft,
            end: Align.bottomRight,
            size: [46, 46],
          }),
          boxShadow: boxShadow([{ color: withAlpha(AppColors.auroraRose, 0.35), blur: 10, offset: [0, 3] }]),
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
        }}
      >
        <Icon name="sports_esports" size={24} color={AppColors.petalWhite} />
      </div>
      <div style={{ width: 12 }} />
      <div style={{ flex: 1, minWidth: 0 }}>
        <div
          style={{
            ...AppTypography.bodyMedium,
            lineHeight: lineHeight(14),
            fontWeight: 700,
            color: AppColors.petalWhite,
            whiteSpace: 'nowrap',
            overflow: 'hidden',
            textOverflow: 'ellipsis',
          }}
        >
          {game.title === '' ? 'Motchi Mini' : game.title}
        </div>
        <div style={{ height: 3 }} />
        <div style={{ ...AppTypography.bodySmall, fontSize: 12, lineHeight: lineHeight(12), color: Derived.textMuted }}>
          {subtitle}
        </div>
      </div>
      <div style={{ width: 8 }} />
      <div
        style={{
          padding: '7px 12px',
          borderRadius: AppRadius.full,
          background: linear([AppColors.deepRose, AppColors.auroraRose], { begin: Align.topLeft, end: Align.bottomRight }),
          display: 'flex',
          alignItems: 'center',
          gap: 4,
        }}
      >
        <span style={{ ...AppTypography.bodySmall, lineHeight: lineHeight(12.5), fontWeight: 700, color: AppColors.petalWhite }}>
          Play
        </span>
        <Icon name="arrow_forward" size={14} color={AppColors.petalWhite} />
      </div>
      <div onClick={(e) => e.stopPropagation()}>
        <MaterialIconButton
          icon="delete_outline"
          size={20}
          tooltip="Remove from shelf"
          color={Derived.textMuted}
          onPressed={onDelete}
        />
      </div>
    </div>
  );
}
