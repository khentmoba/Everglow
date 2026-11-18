import { useState } from 'react';
import { AppColors, withAlpha } from '../../core/theme/colors';
import { CssCurves, orZero } from '../../core/theme/motion';
import { AppTypography } from '../../core/theme/typography';
import { HueGlyph } from '../../shared/widgets/HueGlyph';

const ITEMS = [
  { label: 'Today', icon: 'wb_twilight', hue: AppColors.auroraGold, targetId: 'zone-today' },
  { label: 'Together', icon: 'favorite', hue: AppColors.auroraRose, targetId: 'zone-together' },
  { label: 'Our World', icon: 'public', hue: AppColors.auroraTeal, targetId: 'zone-world' },
  { label: 'Play', icon: 'videogame_asset', hue: AppColors.softLavender, targetId: 'zone-play' },
] as const;

export function DashboardJumpBar({ onJump }: { onJump: (id: string) => void }) {
  return (
    <nav aria-label="Jump to zone" style={{ display: 'grid', gridTemplateColumns: 'repeat(4, minmax(0, 1fr))', gap: 8 }}>
      {ITEMS.map((it) => (
        <JumpChip key={it.targetId} item={it} onJump={onJump} />
      ))}
    </nav>
  );
}

function JumpChip({ item, onJump }: { item: (typeof ITEMS)[number]; onJump: (id: string) => void }) {
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
        minHeight: 72,
        padding: '10px 4px 9px',
        borderRadius: 18,
        background: `linear-gradient(180deg, ${withAlpha(item.hue, hovered ? 0.14 : 0.08)}, ${withAlpha(AppColors.inkDeep, 0.3)})`,
        boxShadow: `inset 0 0 0 1px ${withAlpha(item.hue, hovered ? 0.3 : 0.14)}`,
        transition: `background ${orZero(160)}ms ${CssCurves.easeOutStrong}, box-shadow ${orZero(160)}ms ${CssCurves.easeOutStrong}`,
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        justifyContent: 'center',
        gap: 7,
      }}
    >
      <HueGlyph icon={item.icon} hue={item.hue} size={30} iconSize={15} />
      <span
        style={{
          ...AppTypography.outfitBold,
          fontSize: 12,
          lineHeight: 1.1,
          color: withAlpha(AppColors.petalWhite, hovered ? 0.96 : 0.84),
          whiteSpace: 'nowrap',
        }}
      >
        {item.label}
      </span>
    </button>
  );
}
