// Port of lib/features/dashboard/presentation/widgets/dashboard_jump_bar.dart.
import { useState } from 'react';
import { AppColors, withAlpha } from '../../core/theme/colors';
import { CssCurves, orZero } from '../../core/theme/motion';
import { letterSpacing } from '../../core/theme/paint';
import { AppTypography } from '../../core/theme/typography';
import { Icon } from '../../shared/widgets/Icon';

const ITEMS = [
  { label: 'Today', icon: 'wb_twilight', hue: AppColors.auroraGold, targetId: 'zone-today' },
  { label: 'Together', icon: 'favorite', hue: AppColors.auroraRose, targetId: 'zone-together' },
  { label: 'Our World', icon: 'public', hue: AppColors.auroraTeal, targetId: 'zone-world' },
  { label: 'Play', icon: 'videogame_asset', hue: AppColors.softLavender, targetId: 'zone-play' },
] as const;

export function DashboardJumpBar({ onJump }: { onJump: (id: string) => void }) {
  return (
    <div
      aria-label="Jump to zone"
      style={{
        padding: '10px 12px',
        background: withAlpha(AppColors.inkDeep, 0.42),
        borderRadius: 20,
        border: `1px solid ${withAlpha(AppColors.moonlight, 0.08)}`,
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'flex-start',
      }}
    >
      <div style={{ display: 'flex', alignItems: 'center', alignSelf: 'stretch' }}>
        <div style={{ width: 22, height: 1, background: withAlpha(AppColors.blushGold, 0.3) }} />
        <div style={{ width: 10 }} />
        <span
          style={{
            ...AppTypography.outfitHeading,
            fontSize: 9,
            ...letterSpacing(1.2),
            color: withAlpha(AppColors.blushGold, 0.75),
          }}
        >
          JUMP TO
        </span>
        <div style={{ width: 10 }} />
        <div style={{ flex: 1, height: 1, background: withAlpha(AppColors.moonlight, 0.06) }} />
      </div>
      <div style={{ height: 10 }} />
      <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8 }}>
        {ITEMS.map((it) => (
          <JumpChip key={it.targetId} item={it} onJump={onJump} />
        ))}
      </div>
    </div>
  );
}

function JumpChip({
  item,
  onJump,
}: {
  item: (typeof ITEMS)[number];
  onJump: (id: string) => void;
}) {
  const [hovered, setHovered] = useState(false);
  return (
    <button
      type="button"
      className="bare-button"
      aria-label={`Jump to ${item.label}`}
      onMouseEnter={() => setHovered(true)}
      onMouseLeave={() => setHovered(false)}
      onClick={() => onJump(item.targetId)}
      style={{
        padding: '11px 12px',
        background: withAlpha(item.hue, hovered ? 0.16 : 0.08),
        borderRadius: 999,
        border: `1px solid ${withAlpha(item.hue, hovered ? 0.38 : 0.18)}`,
        transition: `background ${orZero(160)}ms ${CssCurves.easeOutStrong}, border-color ${orZero(160)}ms ${CssCurves.easeOutStrong}`,
        display: 'inline-flex',
        alignItems: 'center',
      }}
    >
      <div
        style={{
          width: 22,
          height: 22,
          borderRadius: '50%',
          background: withAlpha(item.hue, 0.16),
          border: `1px solid ${withAlpha(item.hue, 0.32)}`,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
        }}
      >
        <Icon name={item.icon} size={12} color={item.hue} />
      </div>
      <div style={{ width: 7 }} />
      <span
        style={{
          ...AppTypography.outfitHeading,
          fontSize: 11,
          color: withAlpha(AppColors.petalWhite, hovered ? 0.92 : 0.78),
        }}
      >
        {item.label}
      </span>
    </button>
  );
}
