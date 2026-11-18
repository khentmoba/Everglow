// Port of lib/features/bucket_list/presentation/widgets/bucket_kanban_board.dart.
import { useViewport } from '../../core/system/viewport';
import { AppColors, Derived, withAlpha } from '../../core/theme/colors';
import { AppRadius } from '../../core/theme/layout';
import { lineHeight } from '../../core/theme/paint';
import { AppTypography } from '../../core/theme/typography';
import { Icon } from '../../shared/widgets/Icon';
import { BucketItemCard } from './BucketItemCard';
import type { BucketItem, BucketStatus } from './bucketListService';
import { BUCKET_STATUSES, sortDreams, statusHue, statusIcon, statusLabel } from './bucketUi';

export function BucketKanbanBoard({
  items,
  currentUsername,
  onAdd,
}: {
  items: BucketItem[];
  currentUsername: string;
  onAdd: () => void;
}) {
  return (
    <div
      className="no-scrollbar"
      style={{ flex: 1, minHeight: 0, display: 'flex', overflowX: 'auto', padding: '4px 16px 96px', boxSizing: 'border-box' }}
    >
      {BUCKET_STATUSES.map((s) => (
        <DreamColumn
          key={s}
          status={s}
          items={items.filter((i) => i.status === s)}
          currentUsername={currentUsername}
          onAdd={s === 'wish' ? onAdd : undefined}
        />
      ))}
    </div>
  );
}

function DreamColumn({
  status,
  items,
  currentUsername,
  onAdd,
}: {
  status: BucketStatus;
  items: BucketItem[];
  currentUsername: string;
  onAdd?: () => void;
}) {
  const { width } = useViewport();
  const sorted = [...items].sort(sortDreams);
  const hue = statusHue(status);
  const columnWidth = width < 560 ? width * 0.78 : 300;
  return (
    <div
      style={{
        width: columnWidth,
        flexShrink: 0,
        marginRight: 12,
        background: Derived.panelGlass,
        borderRadius: AppRadius.x2,
        border: `1px solid ${withAlpha(hue, 0.16)}`,
        display: 'flex',
        flexDirection: 'column',
      }}
    >
      <div
        style={{
          padding: '12px 14px',
          background: `linear-gradient(135deg, ${withAlpha(hue, 0.16)}, ${withAlpha(hue, 0.04)})`,
          borderRadius: `${AppRadius.x2 - 1}px ${AppRadius.x2 - 1}px 0 0`,
          display: 'flex',
          alignItems: 'center',
        }}
      >
        <div
          style={{
            width: 30,
            height: 30,
            boxSizing: 'border-box',
            borderRadius: '50%',
            background: withAlpha(hue, 0.14),
            border: `1px solid ${withAlpha(hue, 0.4)}`,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
          }}
        >
          <Icon name={statusIcon(status)} size={15} color={hue} />
        </div>
        <div style={{ width: 10 }} />
        <div style={{ flex: 1, ...AppTypography.outfitBold, fontSize: 13, lineHeight: lineHeight(13), color: hue }}>
          {statusLabel(status)}
        </div>
        <div style={{ padding: '4px 9px', borderRadius: AppRadius.full, background: withAlpha(hue, 0.14) }}>
          <span style={{ ...AppTypography.outfitBold, fontSize: 11, lineHeight: lineHeight(11), color: hue }}>
            {sorted.length}
          </span>
        </div>
      </div>
      {sorted.length === 0 ? (
        <div style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center' }}>
          <Icon name={statusIcon(status)} size={28} color={withAlpha(hue, 0.35)} />
          <div style={{ height: 8 }} />
          <div
            style={{
              ...AppTypography.outfitWhite,
              fontSize: 12,
              lineHeight: lineHeight(12),
              color: withAlpha(AppColors.petalWhite, 0.45),
            }}
          >
            {status === 'completed' ? 'None fulfilled yet' : `No ${statusLabel(status).toLowerCase()} dreams`}
          </div>
        </div>
      ) : (
        <div className="no-scrollbar" style={{ flex: 1, minHeight: 0, overflowY: 'auto', padding: '10px 10px 4px' }}>
          {sorted.map((it) => (
            <BucketItemCard key={it.id} item={it} currentUsername={currentUsername} enableSwipe={false} />
          ))}
        </div>
      )}
      {onAdd && (
        <div style={{ padding: '4px 10px 10px' }}>
          <button
            type="button"
            className="bare-button"
            aria-label="Plant a new dream"
            onClick={onAdd}
            style={{
              width: '100%',
              padding: '11px 0',
              borderRadius: AppRadius.lg,
              background: withAlpha(AppColors.moonlight, 0.05),
              border: `1px solid ${withAlpha(AppColors.blushGold, 0.18)}`,
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              cursor: 'pointer',
            }}
          >
            <Icon name="add" size={15} color={withAlpha(AppColors.blushGold, 0.8)} />
            <div style={{ width: 6 }} />
            <span
              style={{
                ...AppTypography.outfitBold,
                fontSize: 12,
                lineHeight: lineHeight(12),
                color: withAlpha(AppColors.blushGold, 0.8),
              }}
            >
              Plant a dream
            </span>
          </button>
        </div>
      )}
    </div>
  );
}
