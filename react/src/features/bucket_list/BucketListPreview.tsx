// Port of lib/features/bucket_list/presentation/widgets/bucket_list_preview.dart.
import { useState } from 'react';
import { useNavigate } from 'react-router';
import { AppColors, withAlpha } from '../../core/theme/colors';
import { AppRadius } from '../../core/theme/layout';
import { linear } from '../../core/theme/paint';
import { AppTypography } from '../../core/theme/typography';
import { useSource } from '../../core/utils/liveSource';
import { Icon } from '../../shared/widgets/Icon';
import { bucketListService, type BucketItem } from './bucketListService';

const HUE = AppColors.blushGold;

export function BucketListPreview() {
  const navigate = useNavigate();
  const [hovered, setHovered] = useState(false);
  const items = useSource<BucketItem[] | null>(() => bucketListService.watchPreview(12), [], null);

  const completed = items ? items.filter((i) => i.status === 'completed').length : 0;
  const total = items ? items.length : 0;
  const progress = total > 0 ? completed / total : 0;
  const wishes = items ? items.filter((i) => i.status === 'wish').slice(0, 3) : [];

  const subtitle = !items
    ? 'Loading our dreams…'
    : total === 0
      ? 'Plant your first star together'
      : completed > 0
        ? `${completed} of ${total} fulfilled • ${Math.round(progress * 100)}%`
        : `${total} ${total === 1 ? 'dream' : 'dreams'} wishing to come true`;

  return (
    <button
      type="button"
      className="bare-button"
      onMouseEnter={() => setHovered(true)}
      onMouseLeave={() => setHovered(false)}
      onClick={() => navigate('/bucket-list')}
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
            <Icon name="auto_awesome" size={18} color={HUE} />
          </div>
          <div style={{ width: 12 }} />
          <div style={{ flex: 1, minWidth: 0 }}>
            <div style={{ ...AppTypography.cormorantBold, fontSize: 20, lineHeight: 1.1, color: AppColors.petalWhite }}>
              Our Bucket List
            </div>
            <div
              style={{ ...AppTypography.outfitWhite, fontSize: 11, color: withAlpha(AppColors.petalWhite, 0.5), marginTop: 2 }}
            >
              {subtitle}
            </div>
          </div>
          <Icon name="chevron_right" size={18} color={withAlpha(HUE, hovered ? 0.9 : 0.55)} />
        </div>

        <div style={{ height: 12 }} />
        <div style={{ height: 4, borderRadius: 999, background: withAlpha(HUE, 0.12), overflow: 'hidden' }}>
          <div style={{ width: `${(progress * 100).toFixed(1)}%`, height: '100%', background: HUE, borderRadius: 999 }} />
        </div>

        <div style={{ height: 12 }} />
        <div
          style={{
            height: 1,
            background: linear([AppColors.transparent, withAlpha(AppColors.petalWhite, 0.07), AppColors.transparent]),
          }}
        />
        <div style={{ height: 10 }} />

        {items == null ? (
          <div style={{ ...AppTypography.outfitMuted, fontSize: 11 }}>Loading…</div>
        ) : wishes.length > 0 ? (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
            {wishes.map((w) => (
              <div
                key={w.id}
                style={{
                  padding: '8px 10px',
                  borderRadius: AppRadius.md,
                  background: withAlpha(HUE, 0.06),
                  border: `1px solid ${withAlpha(HUE, 0.14)}`,
                  display: 'flex',
                  alignItems: 'center',
                  gap: 8,
                }}
              >
                <Icon name="star_outline" size={14} color={HUE} />
                <span style={{ ...AppTypography.outfitWhite, fontSize: 12, color: AppColors.petalWhite, flex: 1 }}>
                  {w.title}
                </span>
              </div>
            ))}
          </div>
        ) : (
          <div
            style={{
              padding: '8px 0',
              textAlign: 'center',
              ...AppTypography.outfitWhite,
              fontSize: 11.5,
              color: withAlpha(AppColors.petalWhite, 0.55),
            }}
          >
            All wishes are becoming memories ✨
          </div>
        )}
      </div>
    </button>
  );
}
