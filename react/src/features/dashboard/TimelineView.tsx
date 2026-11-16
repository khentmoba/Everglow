// Port of lib/features/dashboard/presentation/widgets/timeline_view.dart.
import { useState } from 'react';
import { AppColors, Derived, withAlpha } from '../../core/theme/colors';
import { AppRadius, AppSpacing } from '../../core/theme/layout';
import { Align, letterSpacing, linear } from '../../core/theme/paint';
import { AppTypography } from '../../core/theme/typography';
import { useSource } from '../../core/utils/liveSource';
import { CircularProgress } from '../../shared/widgets/CircularProgress';
import { Icon } from '../../shared/widgets/Icon';
import { MILESTONE_META, milestoneService, type Milestone } from './milestoneService';

export function TimelineView() {
  const milestones = useSource<Milestone[] | null>(() => milestoneService.milestonesPreview(12), [], null);
  const [selected, setSelected] = useState<Milestone | null>(null);

  return (
    <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
      <div style={{ padding: `${AppSpacing.x3}px ${AppSpacing.x3}px ${AppSpacing.sm}px`, width: '100%', display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
        <div
          style={{
            padding: `6px ${AppSpacing.md}px`,
            background: withAlpha(AppColors.moonlight, 0.06),
            borderRadius: 999,
            border: `1px solid ${withAlpha(AppColors.moonlight, 0.12)}`,
            display: 'inline-flex',
            alignItems: 'center',
            gap: 6,
          }}
        >
          <Icon name="favorite" size={10} color={AppColors.auroraRose} />
          <span style={{ ...AppTypography.outfitHeading, fontSize: 10, ...letterSpacing(3.0), color: AppColors.blushGold }}>
            FOR CLAIR
          </span>
        </div>

        <div style={{ height: AppSpacing.md }} />

        <div style={{ display: 'flex', alignItems: 'center', width: '100%' }}>
          <div style={{ flex: 1, height: 1, background: linear([AppColors.transparent, withAlpha(AppColors.blushGold, 0.45)]) }} />
          <div style={{ padding: `0 ${AppSpacing.lg}px` }}>
            <span
              style={{
                ...AppTypography.cormorantBlack,
                fontSize: 26,
                ...letterSpacing(3.0),
                color: AppColors.petalWhite,
                textShadow: `0 0 8.6px ${withAlpha(AppColors.deepRose, 0.45)}, 0 2px 2.8px ${withAlpha(AppColors.black, 0.35)}`,
                whiteSpace: 'nowrap',
              }}
            >
              LIVING ARCHIVE
            </span>
          </div>
          <div style={{ flex: 1, height: 1, background: linear([withAlpha(AppColors.blushGold, 0.45), AppColors.transparent]) }} />
        </div>

        <div style={{ height: AppSpacing.sm }} />
        <span style={{ ...AppTypography.handwrittenTitle, fontSize: 19, color: withAlpha(AppColors.blushGold, 0.92) }}>
          little moments, kept forever
        </span>
        {milestones && milestones.length > 0 && (
          <>
            <div style={{ height: AppSpacing.sm }} />
            <span style={{ ...AppTypography.outfitWhite, fontSize: 11, ...letterSpacing(1.6), color: withAlpha(AppColors.roseQuartz, 0.62) }}>
              ♡ {milestones.length} frame{milestones.length === 1 ? '' : 's'} kept ♡
            </span>
          </>
        )}
      </div>

      <div style={{ width: '100%', height: 520, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
        {milestones == null ? (
          <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 8 }}>
            <CircularProgress size={24} strokeWidth={2} color={withAlpha(AppColors.deepRose, 0.5)} />
            <span style={{ ...AppTypography.outfitWhite, fontSize: 12, color: withAlpha(AppColors.roseQuartz, 0.5) }}>
              Loading memories...
            </span>
          </div>
        ) : (
          <div className="no-scrollbar" style={{ width: '100%', overflowX: 'auto', padding: '0 24px', scrollSnapType: 'x mandatory' }}>
            <div style={{ display: 'flex', gap: 16, width: 'max-content', margin: '0 auto' }}>
              {milestones.map((m) => (
                <MilestoneCarouselCard key={m.id} milestone={m} onTap={() => setSelected(m)} />
              ))}
            </div>
          </div>
        )}
      </div>
      <div style={{ height: 20 }} />

      {selected && (
        <div
          onClick={() => setSelected(null)}
          style={{
            position: 'fixed',
            inset: 0,
            background: withAlpha(AppColors.inkDeep, 0.72),
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
              maxWidth: 480,
              borderRadius: 28,
              overflow: 'hidden',
              background: linear([AppColors.silk, AppColors.velvet, AppColors.inkDeep]),
              border: `1px solid ${withAlpha(AppColors.blushGold, 0.35)}`,
              padding: 24,
            }}
          >
            {selected.imageUrls[0] && (
              <img
                src={selected.imageUrls[0]}
                alt={selected.title}
                style={{ width: '100%', height: 240, objectFit: 'cover', borderRadius: 16, marginBottom: 16 }}
              />
            )}
            <div style={{ ...AppTypography.cormorantBold, fontSize: 24, color: AppColors.petalWhite }}>
              {selected.title}
            </div>
            <div style={{ ...AppTypography.outfitMuted, fontSize: 12, marginTop: 4 }}>
              {selected.date.toLocaleDateString()} · {selected.author}
            </div>
            <div style={{ ...AppTypography.bodyMedium, marginTop: 12, color: Derived.textHigh }}>
              {selected.description}
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

function MilestoneCarouselCard({ milestone, onTap }: { milestone: Milestone; onTap: () => void }) {
  const meta = MILESTONE_META[milestone.category];
  const img = milestone.imageUrls[0];
  return (
    <button
      type="button"
      className="bare-button"
      aria-label={`Open memory ${milestone.title}`}
      onClick={onTap}
      style={{
        width: 300,
        height: 500,
        scrollSnapAlign: 'center',
        borderRadius: AppRadius.x3,
        overflow: 'hidden',
        background: linear([AppColors.silk, AppColors.velvet, AppColors.inkDeep], {
          begin: Align.topLeft,
          end: Align.bottomRight,
          stops: [0, 0.55, 1],
        }),
        border: `1px solid ${withAlpha(AppColors.blushGold, 0.32)}`,
        display: 'flex',
        flexDirection: 'column',
        flexShrink: 0,
      }}
    >
      <div
        style={{
          height: 1,
          margin: '0 28px',
          background: linear([AppColors.transparent, withAlpha(AppColors.blushGold, 0.6), AppColors.transparent]),
        }}
      />
      <div style={{ flex: 3, position: 'relative', width: '100%', overflow: 'hidden' }}>
        {img ? (
          <img src={img} alt={milestone.title} style={{ width: '100%', height: '100%', objectFit: 'cover', display: 'block' }} />
        ) : (
          <div style={{ width: '100%', height: '100%', background: withAlpha(AppColors.deepRose, 0.08), display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
            <Icon name="image" size={32} color={withAlpha(AppColors.roseQuartz, 0.3)} />
          </div>
        )}
        <div
          style={{
            position: 'absolute',
            top: 12,
            left: 12,
            padding: '6px 10px',
            borderRadius: 999,
            background: Derived.panelGlass,
            border: `1px solid ${withAlpha(AppColors.moonlight, 0.18)}`,
            display: 'inline-flex',
            alignItems: 'center',
            gap: 5,
          }}
        >
          <span style={{ fontSize: 11 }}>{meta.emoji}</span>
          <span style={{ ...AppTypography.outfitHeading, fontSize: 10, ...letterSpacing(1.4), color: Derived.textHigh }}>
            {meta.label.toUpperCase()}
          </span>
        </div>
        {milestone.imageUrls.length > 1 && (
          <div
            style={{
              position: 'absolute',
              top: 12,
              right: 12,
              padding: '4px 9px',
              borderRadius: 999,
              background: Derived.panelGlass,
              border: `1px solid ${withAlpha(AppColors.moonlight, 0.18)}`,
              ...AppTypography.outfitBold,
              fontSize: 10,
            }}
          >
            1 / {milestone.imageUrls.length}
          </div>
        )}
      </div>

      <div style={{ flex: 2, padding: 18, display: 'flex', flexDirection: 'column', justifyContent: 'space-between', textAlign: 'left', width: '100%' }}>
        <div>
          <div style={{ ...AppTypography.cormorantBold, fontSize: 22, color: AppColors.petalWhite }}>{milestone.title}</div>
          <div className="clamp-3" style={{ ...AppTypography.bodySmall, marginTop: 6, color: withAlpha(AppColors.petalWhite, 0.72) }}>
            {milestone.description}
          </div>
        </div>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
          <span style={{ ...AppTypography.outfitBold, fontSize: 11, color: AppColors.blushGold }}>
            {milestone.date.toLocaleDateString(undefined, { month: 'short', day: 'numeric', year: 'numeric' })}
          </span>
          <span style={{ ...AppTypography.outfitMuted, fontSize: 11 }}>by {milestone.author}</span>
        </div>
      </div>
    </button>
  );
}
