// Port of lib/features/dashboard/presentation/widgets/timeline_view.dart
// and milestone_photo.dart.
import { useEffect, useRef, useState } from 'react';
import { motionReduced } from '../../core/theme/motion';
import { AppColors, Derived, withAlpha } from '../../core/theme/colors';
import { AppRadius, AppSpacing } from '../../core/theme/layout';
import { Align, linear } from '../../core/theme/paint';
import { AppTypography } from '../../core/theme/typography';
import { useSource } from '../../core/utils/liveSource';
import { CircularProgress } from '../../shared/widgets/CircularProgress';
import { EverglowSectionHeader } from '../../shared/widgets/EverglowSectionHeader';
import { Icon } from '../../shared/widgets/Icon';
import {
  MILESTONE_META,
  milestoneService,
  resolveMilestoneImageUrl,
  type Milestone,
} from './milestoneService';

function MilestonePhoto({
  path,
  alt,
  style,
}: {
  path: string;
  alt: string;
  style?: React.CSSProperties;
}) {
  const [src, setSrc] = useState<string | null>(() =>
    /^(https?:|data:|blob:|\/)/i.test(path) ? path : null,
  );
  const [failed, setFailed] = useState(false);

  useEffect(() => {
    setFailed(false);
    if (!path) {
      setSrc(null);
      return;
    }
    if (/^(https?:|data:|blob:|\/)/i.test(path)) {
      setSrc(path);
      return;
    }
    let alive = true;
    setSrc(null);
    void resolveMilestoneImageUrl(path).then((resolved) => {
      if (!alive) return;
      if (resolved) setSrc(resolved);
      else setFailed(true);
    });
    return () => {
      alive = false;
    };
  }, [path]);

  if (!path || failed || !src) {
    return (
      <div
        style={{
          width: '100%',
          height: '100%',
          background: withAlpha(AppColors.deepRose, 0.08),
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          ...style,
        }}
      >
        <Icon
          name={failed ? 'broken_image' : 'image'}
          size={28}
          color={withAlpha(AppColors.roseQuartz, 0.4)}
        />
      </div>
    );
  }

  return (
    <img
      src={src}
      alt={alt}
      onError={() => setFailed(true)}
      style={{ width: '100%', height: '100%', objectFit: 'cover', display: 'block', ...style }}
    />
  );
}

export function TimelineView() {
  const milestones = useSource<Milestone[] | null>(() => milestoneService.milestonesPreview(12), [], null);
  const [selected, setSelected] = useState<Milestone | null>(null);
  const [modalPhotoIdx, setModalPhotoIdx] = useState(0);
  const [carouselHovered, setCarouselHovered] = useState(false);
  const scrollerRef = useRef<HTMLDivElement>(null);
  const activeCardRef = useRef(0);
  const reduceAmbient = motionReduced();

  useEffect(() => {
    if (reduceAmbient || carouselHovered || selected != null) return;
    if (!milestones || milestones.length <= 1) return;
    const id = window.setInterval(() => {
      const el = scrollerRef.current;
      if (!el || document.visibilityState !== 'visible') return;
      const stepWidth = 316; // 300px card + 16px gap
      const next = (activeCardRef.current + 1) % milestones.length;
      activeCardRef.current = next;
      if (next === 0) {
        el.scrollTo({ left: 0, behavior: 'smooth' });
      } else {
        el.scrollTo({ left: next * stepWidth, behavior: 'smooth' });
      }
    }, 5500);
    return () => window.clearInterval(id);
  }, [milestones, reduceAmbient, carouselHovered, selected]);

  const scrollCardsBy = (delta: number) => {
    const el = scrollerRef.current;
    if (!el) return;
    el.scrollBy({ left: delta, behavior: 'smooth' });
  };

  return (
    <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
      <div style={{ padding: `${AppSpacing.x3}px 20px ${AppSpacing.sm}px`, width: '100%', boxSizing: 'border-box' }}>
        <EverglowSectionHeader
          label="Living Archive"
          icon="photo_library"
          hue={AppColors.auroraRose}
          trailing={
            milestones && milestones.length > 0 ? (
              <span style={{ ...AppTypography.handwrittenBody, fontSize: 18, lineHeight: 1, color: withAlpha(AppColors.blushGold, 0.9) }}>
                {milestones.length} kept
              </span>
            ) : undefined
          }
        />
        <div style={{ ...AppTypography.handwrittenBody, fontSize: 18, lineHeight: 1.2, color: withAlpha(AppColors.roseQuartz, 0.8), margin: '4px 0 0 36px' }}>
          little moments, kept for Clair
        </div>
      </div>

      <div
        style={{ width: '100%', height: 520, display: 'flex', alignItems: 'center', justifyContent: 'center', position: 'relative' }}
        onMouseEnter={() => setCarouselHovered(true)}
        onMouseLeave={() => setCarouselHovered(false)}
      >
        {milestones == null ? (
          <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 8 }}>
            <CircularProgress size={24} strokeWidth={2} color={withAlpha(AppColors.deepRose, 0.5)} />
            <span style={{ ...AppTypography.outfitWhite, fontSize: 12, color: withAlpha(AppColors.roseQuartz, 0.5) }}>
              Loading memories...
            </span>
          </div>
        ) : (
          <>
            <div
              ref={scrollerRef}
              className="no-scrollbar"
              onScroll={(e) => {
                activeCardRef.current = Math.round(e.currentTarget.scrollLeft / 316);
              }}
              style={{ width: '100%', overflowX: 'auto', padding: '0 24px', scrollSnapType: 'x mandatory' }}
            >
              <div style={{ display: 'flex', gap: 16, width: 'max-content', margin: '0 auto' }}>
                {milestones.map((m) => (
                  <MilestoneCarouselCard
                    key={m.id}
                    milestone={m}
                    reduceAmbient={reduceAmbient}
                    onTap={() => {
                      setModalPhotoIdx(0);
                      setSelected(m);
                    }}
                  />
                ))}
              </div>
            </div>
            {milestones.length > 1 && carouselHovered && (
              <>
                <button
                  type="button"
                  className="bare-button"
                  aria-label="Previous memory"
                  onClick={() => scrollCardsBy(-316)}
                  style={{
                    position: 'absolute',
                    left: 8,
                    top: '50%',
                    transform: 'translateY(-50%)',
                    width: 38,
                    height: 38,
                    borderRadius: '50%',
                    background: withAlpha(AppColors.inkDeep, 0.78),
                    border: `1px solid ${withAlpha(AppColors.blushGold, 0.4)}`,
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    zIndex: 4,
                  }}
                >
                  <Icon name="chevron_left" size={20} color={AppColors.petalWhite} />
                </button>
                <button
                  type="button"
                  className="bare-button"
                  aria-label="Next memory"
                  onClick={() => scrollCardsBy(316)}
                  style={{
                    position: 'absolute',
                    right: 8,
                    top: '50%',
                    transform: 'translateY(-50%)',
                    width: 38,
                    height: 38,
                    borderRadius: '50%',
                    background: withAlpha(AppColors.inkDeep, 0.78),
                    border: `1px solid ${withAlpha(AppColors.blushGold, 0.4)}`,
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    zIndex: 4,
                  }}
                >
                  <Icon name="chevron_right" size={20} color={AppColors.petalWhite} />
                </button>
              </>
            )}
          </>
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
            {selected.imageUrls.length > 0 && (
              <div style={{ position: 'relative', width: '100%', height: 260, borderRadius: 16, overflow: 'hidden', marginBottom: 16 }}>
                <MilestonePhoto
                  path={selected.imageUrls[modalPhotoIdx % selected.imageUrls.length]}
                  alt={selected.title}
                />
                {selected.imageUrls.length > 1 && (
                  <>
                    <button
                      type="button"
                      className="bare-button"
                      aria-label="Previous photo"
                      onClick={() =>
                        setModalPhotoIdx((i) => (i - 1 + selected.imageUrls.length) % selected.imageUrls.length)
                      }
                      style={{
                        position: 'absolute',
                        left: 10,
                        top: '50%',
                        transform: 'translateY(-50%)',
                        width: 34,
                        height: 34,
                        borderRadius: '50%',
                        background: withAlpha(AppColors.inkDeep, 0.72),
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'center',
                      }}
                    >
                      <Icon name="chevron_left" size={18} color={AppColors.petalWhite} />
                    </button>
                    <button
                      type="button"
                      className="bare-button"
                      aria-label="Next photo"
                      onClick={() => setModalPhotoIdx((i) => (i + 1) % selected.imageUrls.length)}
                      style={{
                        position: 'absolute',
                        right: 10,
                        top: '50%',
                        transform: 'translateY(-50%)',
                        width: 34,
                        height: 34,
                        borderRadius: '50%',
                        background: withAlpha(AppColors.inkDeep, 0.72),
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'center',
                      }}
                    >
                      <Icon name="chevron_right" size={18} color={AppColors.petalWhite} />
                    </button>
                    <div
                      style={{
                        position: 'absolute',
                        bottom: 10,
                        right: 10,
                        padding: '3px 9px',
                        borderRadius: 999,
                        background: withAlpha(AppColors.inkDeep, 0.75),
                        ...AppTypography.outfitBold,
                        fontSize: 10,
                        color: AppColors.petalWhite,
                      }}
                    >
                      {(modalPhotoIdx % selected.imageUrls.length) + 1} / {selected.imageUrls.length}
                    </div>
                  </>
                )}
              </div>
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

function MilestoneCarouselCard({
  milestone,
  reduceAmbient,
  onTap,
}: {
  milestone: Milestone;
  reduceAmbient: boolean;
  onTap: () => void;
}) {
  const meta = MILESTONE_META[milestone.category];
  const count = milestone.imageUrls.length;
  const [imgIndex, setImgIndex] = useState(0);
  const [hovered, setHovered] = useState(false);

  useEffect(() => {
    setImgIndex(0);
  }, [milestone.id]);

  useEffect(() => {
    if (reduceAmbient || hovered || count <= 1) return;
    const id = window.setInterval(() => {
      if (document.visibilityState === 'visible') {
        setImgIndex((i) => (i + 1) % count);
      }
    }, 4500);
    return () => window.clearInterval(id);
  }, [count, reduceAmbient, hovered]);

  const activePath = count > 0 ? milestone.imageUrls[imgIndex % count] : '';

  return (
    <button
      type="button"
      className="bare-button"
      aria-label={`Open memory ${milestone.title}`}
      onMouseEnter={() => setHovered(true)}
      onMouseLeave={() => setHovered(false)}
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
        border: `1px solid ${withAlpha(AppColors.blushGold, hovered ? 0.52 : 0.32)}`,
        transform: hovered && !reduceAmbient ? 'translateY(-4px)' : undefined,
        transition: 'transform 220ms cubic-bezier(0.22, 1, 0.36, 1), border-color 220ms ease',
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
        {activePath ? (
          <MilestonePhoto path={activePath} alt={milestone.title} />
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
          <span style={{ ...AppTypography.outfitBold, fontSize: 11, color: Derived.textHigh }}>
            {meta.label}
          </span>
        </div>
        {count > 1 && (
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
              color: AppColors.petalWhite,
            }}
          >
            {(imgIndex % count) + 1} / {count}
          </div>
        )}
        {count > 1 && count <= 6 && (
          <div
            style={{
              position: 'absolute',
              right: 12,
              bottom: 12,
              display: 'flex',
              alignItems: 'center',
              gap: 4,
              padding: '4px 7px',
              borderRadius: 999,
              background: withAlpha(AppColors.inkDeep, 0.65),
            }}
          >
            {milestone.imageUrls.map((_, i) => {
              const active = i === imgIndex % count;
              return (
                <span
                  key={i}
                  style={{
                    width: active ? 14 : 5,
                    height: 5,
                    borderRadius: 99,
                    background: active ? AppColors.blushGold : withAlpha(AppColors.petalWhite, 0.45),
                    transition: 'width 240ms ease',
                  }}
                />
              );
            })}
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
