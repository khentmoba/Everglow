// Port of lib/features/journal/presentation/widgets/journal_entry_card.dart.
import type { CSSProperties } from 'react';
import { useBoxSize } from '../../core/system/useBoxSize';
import { AppColors, withAlpha } from '../../core/theme/colors';
import { AppRadius } from '../../core/theme/layout';
import { Align, linear, lineHeight } from '../../core/theme/paint';
import { AppTypography } from '../../core/theme/typography';
import { EverglowCard } from '../../shared/widgets/EverglowCard';
import { Icon } from '../../shared/widgets/Icon';
import { AuthorDot } from './JournalDetailSheet';
import { categoryInfo, isLong, moodEmoji, preview, type JournalEntry } from './journalService';
import {
  journalAuthorName,
  journalCategoryColor,
  journalNumberFormat,
  journalReadingTime,
  journalRelativeDate,
} from './journalUi';

const clamp = (lines: number): CSSProperties => ({
  display: '-webkit-box',
  WebkitLineClamp: lines,
  WebkitBoxOrient: 'vertical',
  overflow: 'hidden',
});

export function JournalEntryCard({ entry, onTap }: { entry: JournalEntry; onTap: () => void }) {
  const hue = journalCategoryColor(entry.category);
  const cat = categoryInfo(entry.category);
  const title = entry.title === '' ? 'Untitled' : entry.title;
  const author = journalAuthorName(entry.author);
  const semanticLabel = entry.isLocked ? `Locked entry — ${title} by ${author}` : `${title} by ${author}, ${cat.displayName}`;
  const [ref, size] = useBoxSize<HTMLDivElement>();
  const borderWidth = entry.isPinned ? 1.2 : 1;
  const meta = (size: number, alpha: number): CSSProperties => ({
    ...AppTypography.outfitMedium,
    fontSize: size,
    lineHeight: lineHeight(size),
    color: withAlpha(AppColors.petalWhite, alpha),
    whiteSpace: 'nowrap',
  });

  return (
    <EverglowCard
      onTap={onTap}
      semanticLabel={semanticLabel}
      padding={0}
      radius={AppRadius.xl}
      fillColor="transparent"
      boxShadow={[
        { color: withAlpha(AppColors.inkDeep, 0.35), blur: 12, offset: [0, 4] },
        ...(entry.isPinned ? [{ color: withAlpha(AppColors.blushGold, 0.1), blur: 16, offset: [0, 2] as [number, number] }] : []),
      ]}
    >
      <div
        ref={ref}
        style={{
          // Dart also sets color: panelGlass; Skia keeps that paint's 0.62 alpha under the gradient shader.
          background: linear(
            [withAlpha(AppColors.velvet, 0.4 * 0.62), withAlpha(AppColors.inkDeep, 0.7 * 0.62), withAlpha(hue, 0.04 * 0.62)],
            {
              begin: Align.topLeft,
              end: Align.bottomRight,
              size: size ?? [1, 1],
            },
          ),
          borderRadius: AppRadius.xl,
          boxShadow: `inset 0 0 0 ${borderWidth}px ${entry.isPinned ? withAlpha(AppColors.blushGold, 0.36) : withAlpha(AppColors.moonlight, 0.1)}`,
          padding: borderWidth,
          display: 'flex',
          flexDirection: 'column',
        }}
      >
        <div
          style={{
            height: 3.5,
            background: linear([withAlpha(hue, 0.95), withAlpha(hue, 0.35), 'rgba(0,0,0,0)']),
            borderRadius: `${AppRadius.xl}px ${AppRadius.xl}px 0 0`,
          }}
        />
        <div style={{ padding: '14px 18px 16px', display: 'flex', flexDirection: 'column', alignItems: 'flex-start' }}>
          {entry.isSyncing && (
            <>
              <div style={{ display: 'flex', alignItems: 'center' }}>
                <Icon name="cloud_upload" variant="outlined" size={12} color={withAlpha(AppColors.petalWhite, 0.6)} />
                <div style={{ width: 5 }} />
                <span
                  style={{
                    ...AppTypography.outfitWhite,
                    fontSize: 10.5,
                    lineHeight: lineHeight(10.5),
                    color: withAlpha(AppColors.petalWhite, 0.6),
                  }}
                >
                  Saved on this device · syncing
                </span>
              </div>
              <div style={{ height: 8 }} />
            </>
          )}
          {entry.isPinned && (
            <>
              <div
                style={{
                  padding: '3.5px 9px',
                  background: withAlpha(AppColors.blushGold, 0.14),
                  borderRadius: AppRadius.full,
                  border: `1px solid ${withAlpha(AppColors.blushGold, 0.35)}`,
                  display: 'flex',
                  alignItems: 'center',
                }}
              >
                <Icon name="push_pin" size={11} color={AppColors.blushGold} />
                <div style={{ width: 4 }} />
                <span
                  style={{
                    ...AppTypography.outfitBold,
                    fontSize: 10,
                    lineHeight: lineHeight(10),
                    letterSpacing: 0.5,
                    color: AppColors.blushGold,
                  }}
                >
                  Pinned with love
                </span>
              </div>
              <div style={{ height: 10 }} />
            </>
          )}
          <div style={{ alignSelf: 'stretch', display: 'flex', alignItems: 'center' }}>
            <div
              style={{
                padding: '4.5px 10px',
                background: withAlpha(hue, 0.14),
                borderRadius: AppRadius.full,
                border: `1px solid ${withAlpha(hue, 0.32)}`,
                display: 'flex',
                alignItems: 'center',
                flexShrink: 0,
              }}
            >
              <span style={{ fontSize: 11, lineHeight: lineHeight(11) }}>{cat.emoji}</span>
              <div style={{ width: 5 }} />
              <span
                style={{
                  ...AppTypography.outfitBold,
                  fontSize: 10.5,
                  lineHeight: lineHeight(10.5),
                  color: hue,
                  letterSpacing: 0.3,
                }}
              >
                {cat.displayName}
              </span>
            </div>
            {entry.mood != null && (
              <>
                <div style={{ width: 6 }} />
                <div
                  style={{
                    padding: '4.5px 8px',
                    background: withAlpha(AppColors.moonlight, 0.08),
                    borderRadius: AppRadius.full,
                    border: `1px solid ${withAlpha(AppColors.moonlight, 0.1)}`,
                    flexShrink: 0,
                    ...meta(10.5, 0.72),
                  }}
                >
                  {moodEmoji(entry.mood)} {entry.mood}
                </div>
              </>
            )}
            <div style={{ flex: 1 }} />
            {entry.isLocked && (
              <div style={{ paddingRight: 6, display: 'flex' }}>
                <Icon name="lock" size={13} color={withAlpha(AppColors.warmAmber, 0.95)} />
              </div>
            )}
            <span style={meta(11, 0.52)}>{journalRelativeDate(entry.createdAt)}</span>
          </div>
          <div style={{ height: 10 }} />
          <div
            style={{
              ...AppTypography.cormorantBoldWhite,
              fontSize: 22,
              lineHeight: lineHeight(22, 1.22),
              letterSpacing: 0.2,
              ...clamp(2),
            }}
          >
            {title}
          </div>
          <div style={{ height: 8 }} />
          {entry.isLocked ? (
            <div
              style={{
                alignSelf: 'stretch',
                padding: '14px 0',
                background: withAlpha(AppColors.inkDeep, 0.45),
                borderRadius: AppRadius.sm,
                border: `1px solid ${withAlpha(AppColors.warmAmber, 0.2)}`,
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
              }}
            >
              <Icon name="lock_outline" size={15} color={withAlpha(AppColors.warmAmber, 0.85)} />
              <div style={{ width: 8 }} />
              <span
                style={{
                  ...AppTypography.outfitWhite,
                  fontSize: 12,
                  lineHeight: lineHeight(12),
                  fontStyle: 'italic',
                  color: withAlpha(AppColors.petalWhite, 0.68),
                }}
              >
                Sealed with a kiss — tap to open
              </span>
            </div>
          ) : (
            <div
              style={{
                ...AppTypography.outfitWhite,
                fontSize: 13.5,
                lineHeight: lineHeight(13.5, 1.55),
                color: withAlpha(AppColors.petalWhite, 0.76),
                ...clamp(3),
              }}
            >
              {preview(entry) === '' ? 'No content' : preview(entry)}
            </div>
          )}
          {!entry.isLocked && entry.tags.length > 0 && (
            <>
              <div style={{ height: 10 }} />
              <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6 }}>
                {entry.tags.slice(0, 3).map((t, i) => (
                  <span
                    key={`${t}-${i}`}
                    style={{
                      padding: '3.5px 8px',
                      background: withAlpha(AppColors.softLavender, 0.12),
                      borderRadius: AppRadius.full,
                      border: `1px solid ${withAlpha(AppColors.softLavender, 0.18)}`,
                      ...AppTypography.outfitMedium,
                      fontSize: 10.5,
                      lineHeight: lineHeight(10.5),
                      color: AppColors.softLavender,
                    }}
                  >
                    #{t}
                  </span>
                ))}
                {entry.tags.length > 3 && (
                  <span style={{ padding: '3.5px 0', ...meta(10.5, 0.45) }}>+{entry.tags.length - 3}</span>
                )}
              </div>
            </>
          )}
          <div style={{ height: 12 }} />
          <div style={{ alignSelf: 'stretch', height: 1, background: withAlpha(AppColors.moonlight, 0.08) }} />
          <div style={{ height: 10 }} />
          <div style={{ alignSelf: 'stretch', display: 'flex', alignItems: 'center' }}>
            <AuthorDot author={entry.author} size={22} />
            <div style={{ width: 8 }} />
            <span
              style={{
                ...AppTypography.outfitBold,
                fontSize: 11.5,
                lineHeight: lineHeight(11.5),
                color: withAlpha(AppColors.petalWhite, 0.85),
              }}
            >
              {author}
            </span>
            <div style={{ padding: '0 7px' }}>
              <div style={{ width: 3, height: 3, borderRadius: '50%', background: withAlpha(AppColors.petalWhite, 0.35) }} />
            </div>
            <span style={meta(11, 0.48)}>{journalReadingTime(entry.wordCount)}</span>
            <div style={{ flex: 1 }} />
            <span style={meta(11, 0.45)}>{journalNumberFormat(entry.wordCount)} words</span>
            {isLong(entry) && (
              <>
                <div style={{ width: 6 }} />
                <Icon name="auto_stories" size={13} color={AppColors.blushGold} />
              </>
            )}
          </div>
        </div>
      </div>
    </EverglowCard>
  );
}
