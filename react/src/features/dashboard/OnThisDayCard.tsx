// Port of lib/features/dashboard/presentation/widgets/on_this_day_card.dart
// + lib/core/services/on_this_day_service.dart.
import { useEffect, useState } from 'react';
import { useNavigate } from 'react-router';
import { Logger } from '../../core/system/logger';
import { AppColors, withAlpha } from '../../core/theme/colors';
import { AppRadius } from '../../core/theme/layout';
import { orZero } from '../../core/theme/motion';
import { Align, boxShadow, linear, lineHeight } from '../../core/theme/paint';
import { AppTypography } from '../../core/theme/typography';
import { Icon } from '../../shared/widgets/Icon';
import { chatService } from '../chat/chatService';
import { TmdbImages } from '../cinema/cinemaTypes';
import { getWatchListFromThisDay, isWatchedItem } from '../cinema/tmdbService';
import { displayGalleryUrl, getPhotosFromThisDay } from '../gallery/galleryService';
import { FeatureSection, SectionChevron } from './FeatureSection';

type OnThisDaySource = 'gallery' | 'cinema' | 'chat';
type OnThisDayMemory = {
  source: OnThisDaySource;
  date: Date;
  title: string;
  subtitle: string;
  imageUrl?: string;
  posterUrl?: string;
};

const withTimeout = <T,>(p: Promise<T>, ms: number, fallback: T) =>
  Promise.race([p, new Promise<T>((resolve) => window.setTimeout(() => resolve(fallback), ms))]);

/** `OnThisDayService.getAllMemories`: gallery, watch list and chat from today's date in past years, newest first. */
async function getAllMemories(): Promise<OnThisDayMemory[]> {
  try {
    const [photos, items, messages] = await Promise.all([
      getPhotosFromThisDay(),
      getWatchListFromThisDay(),
      chatService.getMessagesFromThisDay(),
    ]);
    const all: OnThisDayMemory[] = [
      ...photos.map((p) => ({
        source: 'gallery' as const,
        date: p.uploadedAt,
        title: p.caption.length > 0 ? p.caption : 'A photo memory',
        subtitle: 'Gallery photo',
        imageUrl: displayGalleryUrl(p.imageUrl, true),
      })),
      ...items.map((item) => ({
        source: 'cinema' as const,
        date: item.addedAt,
        title: item.title,
        subtitle: `You ${isWatchedItem(item) ? 'watched together' : 'added to your list'}`,
        posterUrl: item.posterPath,
      })),
      ...messages.slice(0, 3).map((m) => ({
        source: 'chat' as const,
        date: m.timestamp,
        title: m.text.length > 80 ? `${m.text.slice(0, 80)}...` : m.text,
        subtitle: `${m.sender} said`,
      })),
    ];
    return all.sort((a, b) => b.date.getTime() - a.date.getTime());
  } catch (e) {
    Logger.e('Error fetching on-this-day memories', e);
    return [];
  }
}

const SOURCE_ICON: Record<OnThisDaySource, string> = {
  gallery: 'photo_library',
  cinema: 'local_movies',
  chat: 'chat_bubble',
};
const SOURCE_COLOR: Record<OnThisDaySource, string> = {
  gallery: AppColors.roseQuartz,
  cinema: AppColors.deepRose,
  chat: AppColors.softLavender,
};
const SOURCE_ROUTE: Record<OnThisDaySource, string> = {
  gallery: '/gallery',
  cinema: '/cinema',
  chat: '/sanctuary',
};

export function OnThisDayCard() {
  const navigate = useNavigate();
  const [memories, setMemories] = useState<OnThisDayMemory[]>([]);
  const [revealed, setRevealed] = useState(false);

  useEffect(() => {
    let alive = true;
    void withTimeout(getAllMemories(), 10_000, []).then((list) => {
      if (!alive) return;
      setMemories(list);
      if (list.length > 0) requestAnimationFrame(() => alive && setRevealed(true));
    });
    return () => {
      alive = false;
    };
  }, []);

  if (memories.length === 0) return null;

  return (
    <div style={{ padding: '6px 16px' }}>
      <FeatureSection
        icon="history"
        hue={AppColors.blushGold}
        title="On This Day"
        subtitle={`${memories.length} ${memories.length === 1 ? 'memory' : 'memories'} from the past`}
        trailing={<SectionChevron />}
      >
        <div className="no-scrollbar" style={{ overflowX: 'auto', height: 168 }}>
          <div style={{ display: 'flex', height: '100%', width: 'max-content' }}>
            {memories.map((m, i) => {
              // Interval(delay/800, 1, easeOutCubic) on an 800ms controller.
              const delay = Math.min(i * 100, 600);
              return (
                <div
                  key={i}
                  style={{
                    paddingRight: 12,
                    opacity: revealed ? 1 : 0,
                    transform: `translateY(${revealed ? 0 : 20}px)`,
                    transition: `opacity ${orZero(800 - delay)}ms cubic-bezier(0.33, 1, 0.68, 1) ${orZero(delay)}ms, transform ${orZero(800 - delay)}ms cubic-bezier(0.33, 1, 0.68, 1) ${orZero(delay)}ms`,
                  }}
                >
                  <MemoryCard memory={m} onTap={() => navigate(SOURCE_ROUTE[m.source])} />
                </div>
              );
            })}
          </div>
        </div>
      </FeatureSection>
    </div>
  );
}

function MemoryCard({ memory, onTap }: { memory: OnThisDayMemory; onTap: () => void }) {
  const [hovered, setHovered] = useState(false);
  const [pressed, setPressed] = useState(false);
  const [failed, setFailed] = useState(false);
  const yearsAgo = new Date().getFullYear() - memory.date.getFullYear();
  const poster = memory.posterUrl
    ? memory.posterUrl.startsWith('http')
      ? memory.posterUrl
      : `${TmdbImages.poster}${memory.posterUrl}`
    : '';
  const url = memory.imageUrl ?? poster;
  const hasImage = !!memory.imageUrl || !!memory.posterUrl;
  const icon = SOURCE_ICON[memory.source];
  const color = SOURCE_COLOR[memory.source];
  const scale = pressed ? 0.96 : hovered ? 1.04 : 1;
  return (
    <div
      role="button"
      tabIndex={0}
      onPointerEnter={(e) => e.pointerType === 'mouse' && setHovered(true)}
      onPointerLeave={() => {
        setHovered(false);
        setPressed(false);
      }}
      onPointerDown={() => setPressed(true)}
      onPointerUp={() => setPressed(false)}
      onClick={onTap}
      onKeyDown={(e) => e.key === 'Enter' && onTap()}
      style={{
        width: 150,
        height: '100%',
        boxSizing: 'border-box',
        borderRadius: AppRadius.lg,
        background: linear([withAlpha(AppColors.moonlight, 0.16), withAlpha(AppColors.inkDeep, 0.5)], {
          begin: Align.topLeft,
          end: Align.bottomRight,
        }),
        border: `1px solid ${hovered ? withAlpha(AppColors.blushGold, 0.55) : withAlpha(AppColors.blushGold, 0.18)}`,
        boxShadow: hovered ? boxShadow([{ color: withAlpha(AppColors.blushGold, 0.18), blur: 16, offset: [0, 6] }]) : 'none',
        transformOrigin: '0 0',
        transform: `translateY(${hovered ? -4 : 0}px) scale(${scale})`,
        transition: `transform ${orZero(200)}ms ease-out, border-color ${orZero(200)}ms ease-out, box-shadow ${orZero(200)}ms ease-out`,
        cursor: 'pointer',
        overflow: 'hidden',
        display: 'flex',
        flexDirection: 'column',
      }}
    >
      <div style={{ height: 86, width: 150, position: 'relative', flexShrink: 0 }}>
        {hasImage && !failed ? (
          <>
            <img
              src={url}
              alt=""
              onError={() => setFailed(true)}
              style={{ position: 'absolute', inset: 0, width: '100%', height: '100%', objectFit: 'cover' }}
            />
            <div style={{ position: 'absolute', inset: 0, background: 'linear-gradient(transparent, rgba(0,0,0,0.45))' }} />
          </>
        ) : (
          <CardPlaceholder icon={icon} color={color} />
        )}
      </div>
      <div
        style={{
          flex: 1,
          minHeight: 0,
          padding: '8px 10px',
          display: 'flex',
          flexDirection: 'column',
        }}
      >
        <div
          className="clamp-2"
          style={{
            ...AppTypography.outfitBold,
            fontSize: 11,
            lineHeight: lineHeight(11, 1.2),
            color: AppColors.petalWhite,
          }}
        >
          {memory.title}
        </div>
        <div style={{ flex: 1 }} />
        <div style={{ display: 'flex', alignItems: 'center' }}>
          <Icon name={icon} size={10} color={withAlpha(color, 0.8)} />
          <div style={{ width: 4 }} />
          <span
            style={{
              flex: 1,
              minWidth: 0,
              ...AppTypography.outfitWhite,
              fontSize: 9,
              lineHeight: lineHeight(9),
              color: withAlpha(AppColors.blushGold, 0.85),
              whiteSpace: 'nowrap',
              overflow: 'hidden',
              textOverflow: 'ellipsis',
            }}
          >
            {yearsAgo} {yearsAgo === 1 ? 'year' : 'years'} ago
          </span>
        </div>
      </div>
    </div>
  );
}

function CardPlaceholder({ icon, color }: { icon: string; color: string }) {
  return (
    <div
      style={{
        position: 'absolute',
        inset: 0,
        background: linear([AppColors.velvet, AppColors.twilight, withAlpha(color, 0.2)], {
          begin: Align.topLeft,
          end: Align.bottomRight,
        }),
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
      }}
    >
      <Icon name={icon} size={24} color={withAlpha(color, 0.6)} />
    </div>
  );
}
