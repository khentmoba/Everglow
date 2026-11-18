// Port of animex_motchi_sidebar.dart's floating trigger.
import { AppColors, withAlpha } from '../../core/theme/colors';
import { boxShadow } from '../../core/theme/paint';
import { AppTypography } from '../../core/theme/typography';
import { Icon } from '../../shared/widgets/Icon';
import { Tooltip } from '../../shared/widgets/Tooltip';

export function AnimeXMotchiFloatingTrigger({ onTap }: { onTap: () => void }) {
  return (
    <Tooltip message="Chat with Motchi">
      <button
        type="button"
        className="bare-button"
        onClick={onTap}
        style={{
          padding: '9px 14px',
          background: 'linear-gradient(135deg, #1E1E2C, #13131D)',
          borderRadius: 28,
          border: `1.4px solid ${withAlpha(AppColors.blushGold, 0.7)}`,
          boxShadow: boxShadow([
            { color: 'rgba(0, 0, 0, 0.5)', blur: 16, offset: [0, 6] },
            { color: withAlpha(AppColors.blushGold, 0.35), blur: 20, spread: 1 },
          ]),
          display: 'flex',
          alignItems: 'center',
        }}
      >
        <div
          style={{
            width: 28,
            height: 28,
            boxSizing: 'border-box',
            borderRadius: '50%',
            border: `1.2px solid ${AppColors.blushGold}`,
            overflow: 'hidden',
          }}
        >
          <img
            src="/images/motchi_avatar.webp"
            alt=""
            style={{ width: '100%', height: '100%', objectFit: 'cover', display: 'block' }}
          />
        </div>
        <div style={{ width: 8 }} />
        <span
          style={{
            ...AppTypography.bodyMedium,
            color: AppColors.petalWhite,
            fontSize: 13.5,
            fontWeight: 700,
            letterSpacing: 0.2,
          }}
        >
          Motchi
        </span>
        <div style={{ width: 4 }} />
        <Icon name="auto_awesome" size={14} color={AppColors.blushGold} />
      </button>
    </Tooltip>
  );
}
