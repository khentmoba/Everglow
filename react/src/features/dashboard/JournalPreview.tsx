// Port of lib/features/dashboard/presentation/widgets/journal_preview.dart.
import { useState } from 'react';
import { useNavigate } from 'react-router';
import { AppColors, withAlpha } from '../../core/theme/colors';
import { AppRadius } from '../../core/theme/layout';
import { linear } from '../../core/theme/paint';
import { AppTypography } from '../../core/theme/typography';
import { useSource } from '../../core/utils/liveSource';
import { Icon } from '../../shared/widgets/Icon';
import { journalService, type JournalEntry } from '../journal/journalService';

const HUE = AppColors.softLavender;

export function JournalPreview() {
  const navigate = useNavigate();
  const [hovered, setHovered] = useState(false);
  const entries = useSource<JournalEntry[] | null>(() => journalService.watchPreview(12), [], null);

  const count = entries?.length ?? 0;
  const pinned = entries?.filter((e) => e.isPinned).length ?? 0;
  const totalWords = entries?.reduce((s, e) => s + e.wordCount, 0) ?? 0;
  const recent = entries?.slice(0, 3) ?? [];

  const subtitle = !entries
    ? 'Loading our memories…'
    : count === 0
      ? 'No entries yet — write your first memory'
      : `${count} ${count === 1 ? 'entry' : 'entries'}${pinned > 0 ? ` • ${pinned} pinned` : ''}`;

  return (
    <button
      type="button"
      className="bare-button"
      onMouseEnter={() => setHovered(true)}
      onMouseLeave={() => setHovered(false)}
      onClick={() => navigate('/journal')}
      style={{
        width: '100%',
        position: 'relative',
        textAlign: 'left',
        background: withAlpha(AppColors.inkDeep, 0.42),
        borderRadius: AppRadius.xl,
        border: `1px solid ${hovered ? withAlpha(HUE, 0.38) : withAlpha(AppColors.petalWhite, 0.08)}`,
        transform: hovered ? 'translateY(-2px)' : undefined,
        transition: 'transform 220ms cubic-bezier(0.23, 1, 0.32, 1)',
        overflow: 'hidden',
      }}
    >
      <div
        style={{
          position: 'absolute',
          top: 0,
          left: 20,
          right: 20,
          height: 1.2,
          background: linear([AppColors.transparent, withAlpha(HUE, hovered ? 0.55 : 0.3), AppColors.transparent]),
        }}
      />
      <div style={{ padding: 16 }}>
        <div style={{ display: 'flex', alignItems: 'center' }}>
          <div
            style={{
              width: 36,
              height: 36,
              borderRadius: 11,
              background: withAlpha(HUE, 0.12),
              border: `1px solid ${withAlpha(HUE, 0.25)}`,
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              flexShrink: 0,
            }}
          >
            <Icon name="auto_stories" size={18} color={HUE} />
          </div>
          <div style={{ width: 12 }} />
          <div style={{ flex: 1, minWidth: 0 }}>
            <div style={{ ...AppTypography.cormorantBold, fontSize: 20, lineHeight: 1.1, color: AppColors.petalWhite }}>
              Our Journal
            </div>
            <div style={{ ...AppTypography.outfitWhite, fontSize: 11, color: withAlpha(AppColors.petalWhite, 0.5), marginTop: 2 }}>
              {subtitle}
            </div>
          </div>
          <Icon name="chevron_right" size={18} color={withAlpha(HUE, hovered ? 0.9 : 0.55)} />
        </div>

        <div style={{ height: 12 }} />
        <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
          <div
            style={{
              width: 34,
              height: 34,
              borderRadius: '50%',
              background: withAlpha(HUE, 0.1),
              border: `1px solid ${withAlpha(HUE, 0.25)}`,
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
            }}
          >
            <Icon name="edit_note" size={18} color={HUE} />
          </div>
          <span style={{ ...AppTypography.outfitWhite, fontSize: 11.5, color: withAlpha(AppColors.petalWhite, 0.72) }}>
            {totalWords} words written together
          </span>
        </div>

        <div style={{ height: 12 }} />
        <div style={{ height: 1, background: linear([AppColors.transparent, withAlpha(AppColors.petalWhite, 0.07), AppColors.transparent]) }} />
        <div style={{ height: 10 }} />

        {entries == null ? (
          <div style={{ ...AppTypography.outfitMuted, fontSize: 11 }}>Loading…</div>
        ) : recent.length === 0 ? (
          <div style={{ ...AppTypography.outfitMuted, fontSize: 11.5 }}>Write your first shared reflection ✨</div>
        ) : (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
            {recent.map((e) => (
              <div
                key={e.id}
                style={{
                  padding: '8px 10px',
                  borderRadius: AppRadius.md,
                  background: withAlpha(HUE, 0.06),
                  border: `1px solid ${withAlpha(HUE, 0.14)}`,
                }}
              >
                <div style={{ ...AppTypography.outfitBold, fontSize: 12, color: AppColors.petalWhite }}>{e.title}</div>
                <div className="clamp-2" style={{ ...AppTypography.outfitWhite, fontSize: 11, color: withAlpha(AppColors.petalWhite, 0.6), marginTop: 2 }}>
                  {e.content}
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </button>
  );
}
