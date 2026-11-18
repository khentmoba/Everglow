// Port of lib/shared/widgets/everglow/everglow_pill_nav.dart: the floating
// bottom pill with icon tabs; the selected tab grows a label.
import { AppColors, Derived, withAlpha } from '../../core/theme/colors';
import { boxShadow, lineHeight } from '../../core/theme/paint';
import { AppTypography } from '../../core/theme/typography';
import { Icon } from './Icon';

export type EverglowNavItem = { icon: string; activeIcon: string; label: string; iconVariant?: 'round' | 'outlined' };

export function EverglowPillNav({
  items,
  currentIndex,
  onTap,
}: {
  items: EverglowNavItem[];
  currentIndex: number;
  onTap: (index: number) => void;
}) {
  return (
    <nav
      style={{
        position: 'absolute',
        left: 16,
        right: 16,
        bottom: 12,
        zIndex: 5,
        padding: '6px 8px',
        borderRadius: 28,
        background: AppColors.shimmerBase,
        border: `1px solid ${Derived.border}`,
        boxSizing: 'border-box',
        boxShadow: boxShadow([
          { color: '#0000004D', blur: 24, offset: [0, 10] },
          { color: withAlpha(AppColors.deepRose, 0.35), blur: 24 },
        ]),
        display: 'flex',
        justifyContent: 'space-evenly',
        alignItems: 'center',
      }}
    >
      {items.map((item, i) => {
        const selected = i === currentIndex;
        return (
          <button
            key={item.label}
            type="button"
            className="bare-button"
            aria-label={item.label}
            aria-pressed={selected}
            onClick={() => onTap(i)}
            style={{
              minWidth: 44,
              minHeight: 44,
              padding: '10px 16px',
              borderRadius: 999,
              background: selected ? withAlpha(AppColors.deepRose, 0.15) : 'transparent',
              display: 'flex',
              alignItems: 'center',
              transition: 'background 220ms cubic-bezier(0.23, 1, 0.32, 1)',
            }}
          >
            <Icon
              name={selected ? item.activeIcon : item.icon}
              variant={selected ? 'round' : (item.iconVariant ?? 'outlined')}
              size={22}
              color={selected ? AppColors.roseQuartz : Derived.textMuted}
            />
            {selected && (
              <>
                <div style={{ width: 8 }} />
                <span style={{ ...AppTypography.labelLarge, fontSize: 12, lineHeight: lineHeight(12), color: AppColors.roseQuartz }}>
                  {item.label}
                </span>
              </>
            )}
          </button>
        );
      })}
    </nav>
  );
}
