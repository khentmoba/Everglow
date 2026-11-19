// Port of lib/features/books/presentation/widgets/book_cover_card.dart.
import { useState } from 'react';
import { reduceAmbientMotion } from '../../core/system/device';
import { useViewport } from '../../core/system/viewport';
import { AppColors, withAlpha } from '../../core/theme/colors';
import { Align, boxShadow, linear, lineHeight } from '../../core/theme/paint';
import { AppTypography } from '../../core/theme/typography';
import { Icon } from '../../shared/widgets/Icon';
import { dartStringHash } from '../../shared/utils/dart';
import type { BookItem, BookSearchResult } from './bookTypes';

const cloths = [AppColors.velvet, AppColors.plum, AppColors.silk, AppColors.deepBlack];

function ClothCover({ title, author, width }: { title: string; author: string; width: number }) {
  const cloth = cloths[Math.abs(dartStringHash(title)) % cloths.length];
  const background = linear([cloth, AppColors.inkDeep], {
    begin: Align.topLeft,
    end: Align.bottomRight,
    size: [width, width * 1.5],
  });
  if (width < 80) {
    return (
      <div
        style={{ position: 'absolute', inset: 0, background, display: 'flex', alignItems: 'center', justifyContent: 'center' }}
      >
        <Icon name="menu_book" size={width * 0.4} color={withAlpha(AppColors.auroraGold, 0.6)} />
      </div>
    );
  }
  // FittedBox(scaleDown) around a 110px column inside 14/12/10/12 + 1px + 8px.
  const inner = width - 24 - 2 - 16;
  const scale = Math.min(1, inner / 110);
  return (
    <div style={{ position: 'absolute', inset: 0, background, padding: '12px 10px 12px 14px', boxSizing: 'border-box' }}>
      <div
        style={{
          height: '100%',
          boxSizing: 'border-box',
          border: `1px solid ${withAlpha(AppColors.auroraGold, 0.35)}`,
          borderRadius: 3,
          padding: 8,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          overflow: 'hidden',
        }}
      >
        <div
          style={{
            width: 110,
            flexShrink: 0,
            transform: `scale(${scale})`,
            display: 'flex',
            flexDirection: 'column',
            alignItems: 'center',
          }}
        >
          <div
            style={{
              ...AppTypography.cormorantBold,
              color: AppColors.auroraGold,
              fontSize: 17,
              lineHeight: lineHeight(17, 1.1),
              textAlign: 'center',
              display: '-webkit-box',
              WebkitLineClamp: 5,
              WebkitBoxOrient: 'vertical',
              overflow: 'hidden',
            }}
          >
            {title}
          </div>
          {author && (
            <>
              <div style={{ width: 18, height: 1, margin: '8px 0', background: withAlpha(AppColors.auroraGold, 0.5) }} />
              <div
                className="clamp-2"
                style={{
                  ...AppTypography.outfitBold,
                  color: withAlpha(AppColors.roseQuartz, 0.75),
                  fontSize: 8,
                  lineHeight: lineHeight(8),
                  letterSpacing: 1.4,
                  textAlign: 'center',
                }}
              >
                {author.toUpperCase()}
              </div>
            </>
          )}
        </div>
      </div>
    </div>
  );
}

/** A 2:3 cover with a soft spine highlight and a lettered cloth fallback. */
export function BookCover({
  imageUrl,
  title,
  author = '',
  width,
  radius = 8,
}: {
  imageUrl: string;
  title: string;
  author?: string;
  width: number;
  radius?: number;
}) {
  const viewport = useViewport();
  const [loaded, setLoaded] = useState(false);
  const [failed, setFailed] = useState(false);
  const showImage = imageUrl !== '' && !failed;
  const isOlCover = imageUrl.includes('covers.openlibrary.org');
  const coverSrc = isOlCover ? imageUrl.replace(/-(S|M|L)\.jpg/, width >= 180 ? '-L.jpg' : width >= 100 ? '-M.jpg' : '-S.jpg') : imageUrl;
  const coverSrcSet = isOlCover
    ? [['-S', '120'], ['-M', '300'], ['-L', '600']]
        .map(([size, w]) => `${imageUrl.replace(/-(S|M|L)\.jpg/, `${size}.jpg`)} ${w}w`)
        .join(', ')
    : undefined;
  return (
    <div
      style={{
        position: 'relative',
        width,
        height: width * 1.5,
        flexShrink: 0,
        borderRadius: radius,
        boxShadow: reduceAmbientMotion(viewport)
          ? undefined
          : boxShadow([{ color: withAlpha('#000000', 0.45), blur: 14, offset: [0, 8] }]),
      }}
    >
      <div style={{ position: 'absolute', inset: 0, borderRadius: radius, overflow: 'hidden' }}>
        {(!showImage || !loaded) && <ClothCover title={title} author={author} width={width} />}
        {showImage && (
          <img
            src={coverSrc}
            srcSet={coverSrcSet}
            sizes={`${width}px`}
            alt=""
            loading="lazy"
            decoding="async"
            onLoad={() => setLoaded(true)}
            onError={() => setFailed(true)}
            style={{ position: 'absolute', inset: 0, width: '100%', height: '100%', objectFit: 'contain', display: 'block', opacity: loaded ? 1 : 0, transition: 'opacity 260ms ease' }}
          />
        )}
        <div
          style={{
            position: 'absolute',
            left: 0,
            top: 0,
            bottom: 0,
            width: 10,
            background: linear([withAlpha(AppColors.petalWhite, 0.2), withAlpha(AppColors.petalWhite, 0)], {
              begin: Align.centerLeft,
              end: Align.centerRight,
            }),
          }}
        />
      </div>
    </div>
  );
}

export function BookCoverCard({
  result,
  item,
  width,
  height,
  statusBadge,
  badgeColor,
  progress,
  onClick,
}: {
  result?: BookSearchResult;
  item?: BookItem;
  width: number;
  height?: number;
  statusBadge?: string;
  badgeColor?: string;
  progress?: number;
  onClick: () => void;
}) {
  const title = result?.title ?? item?.title ?? '';
  const author = result?.author ?? item?.author ?? '';
  const coverUrl = result?.coverUrl ?? item?.coverUrl ?? '';
  return (
    <button
      type="button"
      className="bare-button"
      aria-label={author ? `${title}, by ${author}` : title}
      onClick={onClick}
      style={{ width, height, flexShrink: 0, display: 'flex', flexDirection: 'column', alignItems: 'flex-start' }}
    >
      <BookCover imageUrl={coverUrl} title={title} author={author} width={width} />
      {progress != null && (
        <div style={{ width, height: 3, borderRadius: 2, background: withAlpha(AppColors.petalWhite, 0.14), marginTop: 6, overflow: 'hidden' }}>
          <div style={{ height: '100%', width: `${Math.min(100, Math.max(3, progress * 100))}%`, background: AppColors.warmAmber }} />
        </div>
      )}
      <div style={{ height: progress != null ? 6 : 10, flexShrink: 0 }} />
      <div
        className="clamp-2"
        style={{
          ...AppTypography.outfitBold,
          color: AppColors.petalWhite,
          fontSize: 12.5,
          lineHeight: lineHeight(12.5, 1.25),
          width: '100%',
        }}
      >
        {title}
      </div>
      {statusBadge != null ? (
        <div style={{ paddingTop: 3, display: 'flex', alignItems: 'center', width: '100%' }}>
          <div
            style={{ width: 6, height: 6, borderRadius: '50%', flexShrink: 0, background: badgeColor ?? AppColors.roseQuartz }}
          />
          <div style={{ width: 5, flexShrink: 0 }} />
          <div
            className="ellipsis"
            style={{
              ...AppTypography.outfitWhite,
              color: withAlpha(AppColors.roseQuartz, 0.82),
              fontSize: 10.5,
              lineHeight: lineHeight(10.5),
              flex: 1,
              minWidth: 0,
            }}
          >
            {statusBadge}
          </div>
        </div>
      ) : author ? (
        <div
          className="ellipsis"
          style={{
            ...AppTypography.outfitWhite,
            color: withAlpha(AppColors.roseQuartz, 0.82),
            fontSize: 11,
            lineHeight: lineHeight(11),
            paddingTop: 2,
            width: '100%',
          }}
        >
          {author}
        </div>
      ) : null}
      {statusBadge == null && (result?.year || result?.ratingCount) && (
        <div className="ellipsis" style={{ ...AppTypography.outfitWhite, color: withAlpha(AppColors.roseQuartz, 0.6), fontSize: 11.5, lineHeight: lineHeight(11.5), paddingTop: 2, width: '100%' }}>
          {[result?.year, result?.ratingCount ? `${result.ratingCount >= 1000 ? `${(result.ratingCount / 1000).toFixed(0)}k` : result.ratingCount} downloads` : ''].filter(Boolean).join(' · ')}
        </div>
      )}
    </button>
  );
}
