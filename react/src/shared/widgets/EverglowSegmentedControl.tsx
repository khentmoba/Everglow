// Port of lib/shared/widgets/everglow/everglow_segmented_control.dart.
import { AppColors, withAlpha } from '../../core/theme/colors';
import { AppMotion, CssCurves, orZero } from '../../core/theme/motion';
import { lineHeight } from '../../core/theme/paint';
import { AppTypography } from '../../core/theme/typography';
import { Icon } from './Icon';

export type SegmentItem = { label: string; icon: string };

export function EverglowSegmentedControl({
  items,
  selectedIndex,
  onChanged,
  activeColor = AppColors.blushGold,
}: {
  items: SegmentItem[];
  selectedIndex: number;
  onChanged: (i: number) => void;
  activeColor?: string;
}) {
  const t = `${orZero(AppMotion.fast)}ms ${CssCurves.easeOutStrong}`;
  return (
    <div
      style={{
        padding: 5,
        background: withAlpha(AppColors.inkDeep, 0.58),
        borderRadius: 18,
        border: `1px solid ${withAlpha(AppColors.moonlight, 0.1)}`,
        display: 'flex',
      }}
    >
      {items.map((item, i) => {
        const sel = i === selectedIndex;
        return (
          <button
            key={item.label}
            type="button"
            className="bare-button"
            aria-pressed={sel}
            aria-label={item.label}
            onClick={() => onChanged(i)}
            style={{
              flex: 1,
              minWidth: 0,
              minHeight: 44,
              padding: '13px 0',
              borderRadius: 14,
              background: sel ? withAlpha(activeColor, 0.16) : 'transparent',
              border: `1px solid ${sel ? withAlpha(activeColor, 0.42) : 'transparent'}`,
              transition: `background ${t}, border-color ${t}`,
              boxSizing: 'border-box',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
            }}
          >
            <Icon name={item.icon} size={14} color={sel ? activeColor : withAlpha(AppColors.petalWhite, 0.58)} />
            <div style={{ width: 6, flexShrink: 0 }} />
            <span
              className="ellipsis"
              style={{
                ...AppTypography.outfitBold,
                fontSize: 11.5,
                letterSpacing: 0.15,
                lineHeight: lineHeight(11.5),
                color: sel ? activeColor : withAlpha(AppColors.petalWhite, 0.62),
                minWidth: 0,
              }}
            >
              {item.label}
            </span>
          </button>
        );
      })}
    </div>
  );
}
