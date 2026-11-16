// Port of lib/features/dashboard/presentation/widgets/partner_subrow.dart
// and _partner_label.dart.
import type { ReactNode } from 'react';
import { AppColors, withAlpha } from '../../core/theme/colors';
import { letterSpacing, linear } from '../../core/theme/paint';
import { AppTypography } from '../../core/theme/typography';
import { Icon } from '../../shared/widgets/Icon';
import { SHELF_ACCENTS, type ShelfAccentKey } from './ShelfWidgets';

export function partnerEyebrowLabelFor(userName: string): string {
  const lower = userName.toLowerCase();
  if (lower === 'khentsgdz') return 'CLAIR';
  if (lower === 'clairjassen') return 'KHENT';
  return 'PARTNER';
}

export function PartnerSubrow({
  label,
  children,
  accent,
  emptyMessage = 'Nothing here yet.',
  height = 194,
}: {
  label: string;
  children: ReactNode[];
  accent: ShelfAccentKey;
  emptyMessage?: string | null;
  height?: number;
}) {
  const a = SHELF_ACCENTS[accent];
  const isMe = label.toUpperCase() === 'ME';
  const hasItems = children.length > 0;

  return (
    <div style={{ paddingTop: 14 }}>
      <div style={{ display: 'flex', alignItems: 'center' }}>
        <div style={{ width: 28, height: 1.2, background: linear([withAlpha(a.color, 0), withAlpha(a.color, 0.55)]) }} />
        <div style={{ width: 8 }} />
        <div
          style={{
            padding: '3px 8px',
            borderRadius: 999,
            background: isMe ? withAlpha(a.color, 0.14) : withAlpha(AppColors.petalWhite, 0.06),
            border: `1px solid ${isMe ? withAlpha(a.color, 0.32) : withAlpha(AppColors.petalWhite, 0.1)}`,
            display: 'inline-flex',
            alignItems: 'center',
          }}
        >
          <div
            style={{
              width: 6,
              height: 6,
              borderRadius: '50%',
              background: a.color,
              boxShadow: `0 0 4px ${withAlpha(a.color, 0.35)}`,
            }}
          />
          <div style={{ width: 6 }} />
          <span
            style={{
              ...AppTypography.outfitWhite,
              fontSize: 10,
              fontWeight: 800,
              color: isMe ? a.color : withAlpha(AppColors.petalWhite, 0.72),
              ...letterSpacing(1.6),
            }}
          >
            {label.toUpperCase()}
          </span>
        </div>
        <div style={{ width: 8 }} />
        <div style={{ flex: 1, height: 1, background: linear([withAlpha(a.color, 0.22), AppColors.transparent]) }} />
      </div>

      <div style={{ height: 8 }} />
      {hasItems ? (
        <div className="no-scrollbar" style={{ overflowX: 'auto', height }}>
          <div style={{ display: 'flex', gap: 12, width: 'max-content' }}>{children.slice(0, 12)}</div>
        </div>
      ) : emptyMessage != null ? (
        <div
          style={{
            padding: '12px 14px',
            borderRadius: 14,
            background: withAlpha(AppColors.petalWhite, 0.04),
            border: `1px solid ${withAlpha(AppColors.petalWhite, 0.07)}`,
            display: 'flex',
            alignItems: 'center',
            gap: 10,
          }}
        >
          <div
            style={{
              width: 26,
              height: 26,
              borderRadius: 8,
              background: withAlpha(a.color, 0.1),
              border: `1px solid ${withAlpha(a.color, 0.18)}`,
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
            }}
          >
            <Icon name="nights_stay" variant="outlined" size={13} color={withAlpha(a.color, 0.65)} />
          </div>
          <span
            style={{
              ...AppTypography.outfitWhite,
              color: withAlpha(AppColors.petalWhite, 0.48),
              fontStyle: 'italic',
              fontSize: 12,
              lineHeight: 1.35,
            }}
          >
            {emptyMessage}
          </span>
        </div>
      ) : null}
    </div>
  );
}
