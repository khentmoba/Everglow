// Port of lib/features/dashboard/presentation/widgets/timeline_view.dart
// and milestone_photo.dart.
import { useCallback, useEffect, useRef, useState } from 'react';
import { Curves, motionReduced } from '../../core/theme/motion';
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
  getCachedMilestoneImageUrl,
  milestoneService,
  resolveMilestoneImageUrl,
  type Milestone,
} from './milestoneService';

const CARD_WIDTH = 300;
const CARD_GAP = 16;

function MilestonePhoto({
  path,
  alt,
  style,
}: {
  path: string;
  alt: string;
  style?: React.CSSProperties;
}) {
  const [src, setSrc] = useState<string | null>(() => getCachedMilestoneImageUrl(path));
  const [failed, setFailed] = useState(false);

  useEffect(() => {
    setFailed(false);
    if (!path) {
      setSrc(null);
      return;
    }
    const cached = getCachedMilestoneImageUrl(path);
    if (cached) {
      setSrc(cached);
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
      draggable={false}
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
  const cardSlotRefs = useRef<(HTMLDivElement | null)[]>([]);
  const activeCardRef = useRef(0);
  const glideRafRef = useRef<number | null>(null);
  const focusRafRef = useRef<number | null>(null);
  const isGlidingRef = useRef(false);
  const reduceAmbient = motionReduced();

  const updateCardFocus = useCallback(() => {
    const el = scrollerRef.current;
    if (!el) return;
    const viewportCenter = el.scrollLeft + el.clientWidth / 2;
    let nearestIdx = 0;
    let nearestDist = Number.POSITIVE_INFINITY;

    for (let i = 0; i < cardSlotRefs.current.length; i++) {
      const slot = cardSlotRefs.current[i];
      if (!slot) continue;
      const center = slot.offsetLeft + slot.offsetWidth / 2;
      const dist = Math.abs(viewportCenter - center);
      if (dist < nearestDist) {
        nearestDist = dist;
        nearestIdx = i;
      }
      if (!reduceAmbient) {
        const norm = Math.min(1, dist / (CARD_WIDTH + CARD_GAP));
        const scale = 1 - norm * 0.1;
        const opacity = 1 - norm * 0.34;
        slot.style.transform = `scale(${scale.toFixed(4)})`;
        slot.style.opacity = opacity.toFixed(3);
      } else {
        slot.style.transform = '';
        slot.style.opacity = '';
      }
    }

    if (!isGlidingRef.current) {
      activeCardRef.current = nearestIdx;
    }
  }, [reduceAmbient]);

  const cancelGlide = useCallback(() => {
    if (glideRafRef.current != null) {
      cancelAnimationFrame(glideRafRef.current);
      glideRafRef.current = null;
    }
    if (isGlidingRef.current) {
      isGlidingRef.current = false;
      const el = scrollerRef.current;
      if (el) el.style.scrollSnapType = 'x mandatory';
    }
  }, []);

  const glideToCard = useCallback(
    (index: number, durationMs?: number) => {
      const el = scrollerRef.current;
      if (!el || !milestones || milestones.length === 0) return;
      const clamped = ((index % milestones.length) + milestones.length) % milestones.length;
      const slot = cardSlotRefs.current[clamped];
      if (!slot) return;

      const maxScroll = Math.max(0, el.scrollWidth - el.clientWidth);
      const target = Math.max(0, Math.min(maxScroll, slot.offsetLeft + slot.offsetWidth / 2 - el.clientWidth / 2));
      activeCardRef.current = clamped;
      cancelGlide();

      if (reduceAmbient || Math.abs(target - el.scrollLeft) < 1) {
        el.scrollLeft = target;
        updateCardFocus();
        return;
      }

      const start = el.scrollLeft;
      const delta = target - start;
      const duration = durationMs ?? (clamped === 0 ? 950 : 1150);
      const startedAt = performance.now();
      isGlidingRef.current = true;
      el.style.scrollSnapType = 'none';

      const step = (now: number) => {
        const t = Math.min(1, (now - startedAt) / duration);
        const eased = clamped === 0 ? Curves.easeInOut(t) : Curves.easeInOutCubic(t);
        el.scrollLeft = start + delta * eased;
        updateCardFocus();
        if (t < 1) {
          glideRafRef.current = requestAnimationFrame(step);
        } else {
          glideRafRef.current = null;
          isGlidingRef.current = false;
          el.style.scrollSnapType = 'x mandatory';
          updateCardFocus();
        }
      };

      glideRafRef.current = requestAnimationFrame(step);
    },
    [cancelGlide, milestones, reduceAmbient, updateCardFocus],
  );

  useEffect(() => {
    cardSlotRefs.current.length = milestones?.length ?? 0;
    activeCardRef.current = 0;
    const id = requestAnimationFrame(() => updateCardFocus());
    return () => cancelAnimationFrame(id);
  }, [milestones, updateCardFocus]);

  useEffect(() => {
    const onResize = () => updateCardFocus();
    window.addEventListener('resize', onResize);
    return () => {
      window.removeEventListener('resize', onResize);
      cancelGlide();
      if (focusRafRef.current != null) cancelAnimationFrame(focusRafRef.current);
    };
  }, [cancelGlide, updateCardFocus]);

  const carouselInViewRef = useRef(true);

  useEffect(() => {
    if (typeof IntersectionObserver === 'undefined' || !scrollerRef.current) return;
    const observer = new IntersectionObserver(
      (entries) => {
        carouselInViewRef.current = entries[0]?.isIntersecting ?? true;
      },
      { threshold: 0 },
    );
    observer.observe(scrollerRef.current);
    return () => observer.disconnect();
  }, [milestones]);

  useEffect(() => {
    if (reduceAmbient || carouselHovered || selected != null) return;
    if (!milestones || milestones.length <= 1) return;
    let id = 0;
    const start = () => {
      if (id || document.hidden) return;
      id = window.setInterval(() => {
        if (!carouselInViewRef.current) return;
        glideToCard((activeCardRef.current + 1) % milestones.length);
      }, 5500);
    };
    const stop = () => {
      if (!id) return;
      window.clearInterval(id);
      id = 0;
    };
    const onVis = () => {
      if (document.hidden) stop();
      else start();
    };
    start();
    document.addEventListener('visibilitychange', onVis);
    return () => {
      stop();
      document.removeEventListener('visibilitychange', onVis);
    };
  }, [milestones, reduceAmbient, carouselHovered, selected, glideToCard]);

  const handleScroll = () => {
    if (isGlidingRef.current) return;
    if (focusRafRef.current != null) return;
    focusRafRef.current = requestAnimationFrame(() => {
      focusRafRef.current = null;
      updateCardFocus();
    });
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
        onPointerEnter={(e) => {
          if (e.pointerType === 'mouse') setCarouselHovered(true);
        }}
        onPointerLeave={(e) => {
          if (e.pointerType === 'mouse') setCarouselHovered(false);
        }}
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
              onScroll={handleScroll}
              onPointerDown={cancelGlide}
              onWheel={cancelGlide}
              onTouchStart={cancelGlide}
              style={{
                width: '100%',
                overflowX: 'auto',
                paddingBlock: 8,
                paddingInline: `max(16px, calc(50% - ${CARD_WIDTH / 2}px))`,
                boxSizing: 'border-box',
                scrollSnapType: 'x mandatory',
              }}
            >
              <div style={{ display: 'flex', gap: CARD_GAP, width: 'max-content', alignItems: 'center' }}>
                {milestones.map((m, idx) => (
                  <div
                    key={m.id}
                    ref={(el) => {
                      cardSlotRefs.current[idx] = el;
                    }}
                    style={{
                      scrollSnapAlign: 'center',
                      flexShrink: 0,
                      transformOrigin: 'center center',
                    }}
                  >
                    <MilestoneCarouselCard
                      milestone={m}
                      reduceAmbient={reduceAmbient}
                      onTap={() => {
                        setModalPhotoIdx(0);
                        setSelected(m);
                      }}
                    />
                  </div>
                ))}
              </div>
            </div>
            {milestones.length > 1 && carouselHovered && (
              <>
                <button
                  type="button"
                  className="bare-button"
                  aria-label="Previous memory"
                  onClick={() => glideToCard(activeCardRef.current - 1, 650)}
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
                  onClick={() => glideToCard(activeCardRef.current + 1, 650)}
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
                <div
                  style={{
                    display: 'flex',
                    width: '100%',
                    height: '100%',
                    transform: `translate3d(-${(modalPhotoIdx % selected.imageUrls.length) * 100}%, 0, 0)`,
                    transition: reduceAmbient ? 'none' : 'transform 520ms cubic-bezier(0.42, 0, 0.58, 1)',
                  }}
                >
                  {selected.imageUrls.map((url, idx) => (
                    <div key={`${selected.id}-modal-${idx}`} style={{ flex: '0 0 100%', width: '100%', height: '100%' }}>
                      <MilestonePhoto path={url} alt={selected.title} />
                    </div>
                  ))}
                </div>
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
    let id = 0;
    const start = () => {
      if (id || document.hidden) return;
      id = window.setInterval(() => {
        setImgIndex((i) => (i + 1) % count);
      }, 4200);
    };
    const stop = () => {
      if (!id) return;
      window.clearInterval(id);
      id = 0;
    };
    const onVis = () => {
      if (document.hidden) stop();
      else start();
    };
    start();
    document.addEventListener('visibilitychange', onVis);
    return () => {
      stop();
      document.removeEventListener('visibilitychange', onVis);
    };
  }, [count, reduceAmbient, hovered]);

  const activePhotoIdx = count > 0 ? imgIndex % count : 0;

  return (
    <div
      onPointerEnter={(e) => {
        if (e.pointerType === 'mouse') setHovered(true);
      }}
      onPointerLeave={(e) => {
        if (e.pointerType === 'mouse') setHovered(false);
      }}
      style={{
        position: 'relative',
        width: CARD_WIDTH,
        height: 500,
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
      }}
    >
      <button
        type="button"
        className="bare-button"
        aria-label={`Open memory ${milestone.title}`}
        onClick={onTap}
        style={{
          width: '100%',
          height: '100%',
          display: 'flex',
          flexDirection: 'column',
          textAlign: 'left',
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
          {count > 0 ? (
            <div
              data-archive-photo-track=""
              style={{
                display: 'flex',
                width: '100%',
                height: '100%',
                transform: `translate3d(-${activePhotoIdx * 100}%, 0, 0)`,
                transition: reduceAmbient ? 'none' : 'transform 850ms cubic-bezier(0.42, 0, 0.58, 1)',
              }}
            >
              {milestone.imageUrls.map((url, idx) => (
                <div key={`${milestone.id}-photo-${idx}`} style={{ flex: '0 0 100%', width: '100%', height: '100%' }}>
                  <MilestonePhoto path={url} alt={milestone.title} />
                </div>
              ))}
            </div>
          ) : (
            <div style={{ width: '100%', height: '100%', background: withAlpha(AppColors.deepRose, 0.08), display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
              <Icon name="image" size={32} color={withAlpha(AppColors.roseQuartz, 0.3)} />
            </div>
          )}
          <div
            aria-hidden
            style={{
              position: 'absolute',
              top: 0,
              left: 0,
              right: 0,
              height: 64,
              pointerEvents: 'none',
              background: linear([withAlpha(AppColors.inkDeep, 0.48), AppColors.transparent], {
                begin: Align.topCenter,
                end: Align.bottomCenter,
              }),
            }}
          />
          <div
            aria-hidden
            style={{
              position: 'absolute',
              bottom: 0,
              left: 0,
              right: 0,
              height: 84,
              pointerEvents: 'none',
              background: linear([AppColors.transparent, withAlpha(AppColors.inkDeep, 0.72)], {
                begin: Align.topCenter,
                end: Align.bottomCenter,
              }),
            }}
          />
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
              {activePhotoIdx + 1} / {count}
            </div>
          )}
        </div>

        <div style={{ flex: 2, padding: 18, display: 'flex', flexDirection: 'column', justifyContent: 'space-between', textAlign: 'left', width: '100%', boxSizing: 'border-box' }}>
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

      {count > 1 && hovered && (
        <>
          <button
            type="button"
            className="bare-button"
            aria-label={`Previous photo for ${milestone.title}`}
            onClick={(e) => {
              e.stopPropagation();
              setImgIndex((i) => (i - 1 + count) % count);
            }}
            style={{
              position: 'absolute',
              left: 8,
              top: 146,
              transform: 'translateY(-50%)',
              width: 28,
              height: 28,
              borderRadius: '50%',
              background: withAlpha(AppColors.inkDeep, 0.68),
              border: `1px solid ${withAlpha(AppColors.moonlight, 0.24)}`,
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              zIndex: 3,
            }}
          >
            <Icon name="chevron_left" size={16} color={AppColors.petalWhite} />
          </button>
          <button
            type="button"
            className="bare-button"
            aria-label={`Next photo for ${milestone.title}`}
            onClick={(e) => {
              e.stopPropagation();
              setImgIndex((i) => (i + 1) % count);
            }}
            style={{
              position: 'absolute',
              right: 8,
              top: 146,
              transform: 'translateY(-50%)',
              width: 28,
              height: 28,
              borderRadius: '50%',
              background: withAlpha(AppColors.inkDeep, 0.68),
              border: `1px solid ${withAlpha(AppColors.moonlight, 0.24)}`,
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              zIndex: 3,
            }}
          >
            <Icon name="chevron_right" size={16} color={AppColors.petalWhite} />
          </button>
        </>
      )}

      {count > 1 && count <= 6 && (
        <div
          style={{
            position: 'absolute',
            right: 12,
            top: 270,
            display: 'flex',
            alignItems: 'center',
            gap: 4,
            padding: '4px 7px',
            borderRadius: 999,
            background: withAlpha(AppColors.inkDeep, 0.65),
            zIndex: 3,
          }}
        >
          {milestone.imageUrls.map((_, i) => {
            const active = i === activePhotoIdx;
            return (
              <button
                key={i}
                type="button"
                className="bare-button"
                aria-label={`Show photo ${i + 1} of ${count} for ${milestone.title}`}
                onClick={(e) => {
                  e.stopPropagation();
                  setImgIndex(i);
                }}
                style={{
                  width: active ? 14 : 6,
                  height: 6,
                  borderRadius: 99,
                  background: active ? AppColors.blushGold : withAlpha(AppColors.petalWhite, 0.45),
                  transition: 'width 240ms ease, background 240ms ease',
                }}
              />
            );
          })}
        </div>
      )}
    </div>
  );
}
