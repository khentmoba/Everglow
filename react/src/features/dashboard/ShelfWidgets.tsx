// Port of lib/features/dashboard/presentation/widgets/shelf_widgets.dart.
import { useState } from 'react';
import { AppColors, withAlpha } from '../../core/theme/colors';
import { Align, letterSpacing, linear } from '../../core/theme/paint';
import { AppTypography } from '../../core/theme/typography';
import { Icon } from '../../shared/widgets/Icon';

export type ShelfAccentKey = 'cinema' | 'anime' | 'books' | 'manga' | 'gallery';

export type ShelfAccent = {
  label: string;
  color: string;
  glow: string;
  icon: string;
};

export const SHELF_ACCENTS: Record<ShelfAccentKey, ShelfAccent> = {
  cinema: { label: 'Cinema', color: AppColors.roseQuartz, glow: AppColors.deepRose, icon: 'local_movies' },
  anime: { label: 'Anime', color: AppColors.softLavender, glow: '#8E5DA0', icon: 'auto_awesome' },
  books: { label: 'Books', color: AppColors.warmAmber, glow: '#B87800', icon: 'menu_book' },
  manga: { label: 'Manga', color: '#E8B4BC', glow: '#AD1457', icon: 'import_contacts' },
  gallery: { label: 'Gallery', color: AppColors.roseQuartz, glow: '#880E4F', icon: 'photo_library' },
};

export type ShelfOwner = { name: string; color: string };

export function resolveTmdbCardUrl(url: string): string {
  if (!url) return '';
  if (url.startsWith('http') || url.startsWith('/')) return url;
  if (url.startsWith('assets/')) return `/${url.slice('assets/'.length)}`;
  return `https://image.tmdb.org/t/p/w342${url.startsWith('/') ? '' : '/'}${url}`;
}

export function ShelfHeader({
  accent,
  title,
  itemCount,
  badge,
  tagline,
  onViewAll,
}: {
  accent: ShelfAccentKey;
  title: string;
  itemCount: number;
  badge?: string;
  /** A handwritten line under the title; replaces the title count. */
  tagline?: string;
  onViewAll: () => void;
}) {
  const a = SHELF_ACCENTS[accent];
  const [hovered, setHovered] = useState(false);

  return (
    <div style={{ display: 'flex', alignItems: 'center' }}>
      <div
        style={{
          width: 42,
          height: 42,
          borderRadius: 12,
          background: linear([withAlpha(a.color, 0.22), withAlpha(a.glow, 0.14), withAlpha(a.glow, 0.04)], {
            begin: Align.topLeft,
            end: Align.bottomRight,
            stops: [0, 0.6, 1],
            size: [42, 42],
          }),
          border: `1px solid ${withAlpha(a.color, 0.32)}`,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          flexShrink: 0,
        }}
      >
        <Icon name={a.icon} variant="outlined" size={20} color={a.color} />
      </div>
      <div style={{ width: 12 }} />
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ display: 'flex', alignItems: 'center' }}>
          <span
            style={{
              ...AppTypography.cormorantBold,
              fontSize: 27,
              lineHeight: 0.95,
              letterSpacing: -0.2,
              color: AppColors.petalWhite,
              whiteSpace: 'nowrap',
              overflow: 'hidden',
              textOverflow: 'ellipsis',
            }}
          >
            {title}
          </span>
          {badge && (
            <span
              style={{
                marginLeft: 8,
                padding: '2px 8px',
                borderRadius: 999,
                background: withAlpha(a.color, 0.16),
                border: `1px solid ${withAlpha(a.color, 0.35)}`,
                ...AppTypography.outfitBold,
                fontSize: 10,
                color: a.color,
              }}
            >
              {badge}
            </span>
          )}
        </div>
        <div style={{ height: 4 }} />
        {tagline != null ? (
          <div className="ellipsis" style={{ ...AppTypography.handwrittenBody, fontSize: 16, lineHeight: 1.1, color: withAlpha(a.color, 0.85) }}>
            {tagline}
          </div>
        ) : (
        <div style={{ display: 'flex', alignItems: 'center' }}>
          <div style={{ width: 18, height: 1, background: linear([withAlpha(a.color, 0), withAlpha(a.color, 0.55)]) }} />
          <div style={{ width: 7 }} />
          <span
            style={{
              ...AppTypography.outfitWhite,
              fontSize: 10.5,
              fontWeight: 600,
              color: withAlpha(AppColors.petalWhite, 0.48),
              ...letterSpacing(1.0),
            }}
          >
            {itemCount === 0 ? 'curated together' : `${itemCount} ${itemCount === 1 ? 'title' : 'titles'}  •  shared`}
          </span>
        </div>
        )}
      </div>

      <button
        type="button"
        className="bare-button"
        onMouseEnter={() => setHovered(true)}
        onMouseLeave={() => setHovered(false)}
        onClick={onViewAll}
        style={{
          padding: '7px 13px',
          borderRadius: 999,
          background: hovered ? withAlpha(a.color, 0.16) : withAlpha(AppColors.moonlight, 0.07),
          border: `1px solid ${withAlpha(a.color, hovered ? 0.55 : 0.32)}`,
          display: 'inline-flex',
          alignItems: 'center',
        }}
      >
        <span
          style={{
            ...AppTypography.outfitBold,
            fontSize: 11.5,
            color: hovered ? AppColors.petalWhite : withAlpha(a.color, 0.95),
            letterSpacing: 0.5,
          }}
        >
          View All
        </span>
        <div style={{ width: hovered ? 4 : 2 }} />
        <Icon name="arrow_forward" size={14} color={a.color} />
      </button>
    </div>
  );
}

export function ShelfCard({
  accent,
  imageUrl,
  title,
  subtitle,
  topBadge,
  owners,
  progress,
  onTap,
}: {
  accent: ShelfAccentKey;
  imageUrl: string;
  title: string;
  subtitle?: string;
  topBadge?: string;
  /** Initials of whose shelf this title is on, shown as small marks in the corner. */
  owners?: ShelfOwner[];
  /** 0 to 1; draws a thin progress line along the bottom. */
  progress?: number;
  onTap?: () => void;
}) {
  const a = SHELF_ACCENTS[accent];
  const [hovered, setHovered] = useState(false);
  const src = resolveTmdbCardUrl(imageUrl);

  return (
    <button
      type="button"
      className="bare-button"
      onMouseEnter={() => setHovered(true)}
      onMouseLeave={() => setHovered(false)}
      onClick={onTap}
      style={{
        position: 'relative',
        width: 128,
        height: 186,
        borderRadius: 16,
        overflow: 'hidden',
        border: `1px solid ${hovered && onTap ? withAlpha(a.color, 0.52) : withAlpha(AppColors.petalWhite, 0.1)}`,
        background: AppColors.velvet,
        transform: hovered && onTap ? 'translateY(-6px) scale(1.03)' : undefined,
        transition: 'transform 260ms cubic-bezier(0.215, 0.61, 0.355, 1)',
        flexShrink: 0,
      }}
    >
      {src ? (
        <img src={src} alt={title} decoding="async" style={{ width: '100%', height: '100%', objectFit: 'cover', display: 'block' }} />
      ) : (
        <div style={{ width: '100%', height: '100%', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
          <Icon name={a.icon} size={28} color={withAlpha(a.color, 0.45)} />
        </div>
      )}
      {topBadge && (
        <div
          style={{
            position: 'absolute',
            top: 8,
            left: 8,
            padding: '2px 7px',
            borderRadius: 999,
            background: withAlpha(AppColors.inkDeep, 0.78),
            border: `1px solid ${withAlpha(a.color, 0.45)}`,
            ...AppTypography.outfitBold,
            fontSize: 9,
            color: a.color,
          }}
        >
          {topBadge}
        </div>
      )}
      {owners && owners.length > 0 && (
        <div style={{ position: 'absolute', top: 8, right: 8, display: 'flex', gap: 4 }}>
          {owners.map((o) => (
            <span
              key={o.name}
              title={o.name}
              aria-label={o.name}
              style={{
                width: 22,
                height: 22,
                borderRadius: '50%',
                background: o.color,
                border: `1.5px solid ${withAlpha(AppColors.inkDeep, 0.85)}`,
                boxShadow: `0 2px 6px ${withAlpha(AppColors.inkDeep, 0.5)}`,
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                ...AppTypography.outfitBold,
                fontSize: 10.5,
                color: AppColors.inkDeep,
              }}
            >
              {o.name.charAt(0).toUpperCase()}
            </span>
          ))}
        </div>
      )}
      {progress != null && (
        <div style={{ position: 'absolute', left: 0, right: 0, bottom: 0, height: 3, background: withAlpha(AppColors.petalWhite, 0.12), zIndex: 1 }}>
          <div style={{ width: `${Math.round(Math.min(1, Math.max(0, progress)) * 100)}%`, height: '100%', background: a.color }} />
        </div>
      )}
      {(title || subtitle) && (
        <div
          style={{
            position: 'absolute',
            left: 0,
            right: 0,
            bottom: 0,
            padding: '22px 8px 8px',
            background: linear([AppColors.transparent, withAlpha(AppColors.inkDeep, 0.92)], {
              begin: Align.topCenter,
              end: Align.bottomCenter,
            }),
            textAlign: 'left',
          }}
        >
          {title && (
            <div className="clamp-2" style={{ ...AppTypography.outfitBold, fontSize: 11.5, color: AppColors.petalWhite }}>
              {title}
            </div>
          )}
          {subtitle && (
            <div style={{ ...AppTypography.outfitWhite, fontSize: 9.5, color: withAlpha(a.color, 0.9), marginTop: 2 }}>
              {subtitle}
            </div>
          )}
        </div>
      )}
    </button>
  );
}
