// Port of lib/features/subs/presentation/widgets/sub_card.dart.
import { useBoxSize } from '../../core/system/useBoxSize';
import { AppColors, withAlpha } from '../../core/theme/colors';
import { AppRadius } from '../../core/theme/layout';
import { AppMotion, orZero } from '../../core/theme/motion';
import { Align, linear, lineHeight, mixedLineHeight } from '../../core/theme/paint';
import { AppTypography } from '../../core/theme/typography';
import { Icon } from '../../shared/widgets/Icon';
import { formatPeso } from '../../shared/utils/text';
import { cycleSuffix, daysUntilRenewal, payerName, type SubPayer, type Subscription } from './subsService';

export function subPayerHue(payer: SubPayer): string {
  return payer === 'khent' ? AppColors.auroraTeal : payer === 'clair' ? AppColors.auroraRose : AppColors.blushGold;
}

export function renewalLabel(days: number) {
  if (days <= 0) return 'today';
  if (days === 1) return 'tomorrow';
  return `in ${days}d`;
}

export function SubCard({ sub, onTap }: { sub: Subscription; onTap: () => void }) {
  const days = daysUntilRenewal(sub);
  const hue = subPayerHue(sub.payer);
  const urgent = days <= 3;
  const [ref, size] = useBoxSize<HTMLDivElement>();
  return (
    <div
      ref={ref}
      role="button"
      tabIndex={0}
      aria-label={`${sub.name}, ${formatPeso(sub.price)}${cycleSuffix(sub)}, renews ${renewalLabel(days)}`}
      onClick={onTap}
      onKeyDown={(e) => (e.key === 'Enter' || e.key === ' ') && onTap()}
      style={{
        marginBottom: 10,
        padding: '14px 16px',
        background: linear([withAlpha(AppColors.velvet, 0.92), withAlpha(AppColors.inkDeep, 0.92)], {
          begin: Align.topLeft,
          end: Align.bottomRight,
          size,
        }),
        borderRadius: AppRadius.xl,
        border: `1px solid ${urgent ? withAlpha(AppColors.error, 0.45) : withAlpha(AppColors.moonlight, 0.1)}`,
        transition: `border-color ${orZero(AppMotion.fast)}ms linear`,
        display: 'flex',
        alignItems: 'center',
        cursor: 'pointer',
      }}
    >
      <div
        style={{
          width: 46,
          height: 46,
          borderRadius: '50%',
          background: withAlpha(hue, 0.14),
          border: `1px solid ${withAlpha(hue, 0.45)}`,
          boxSizing: 'border-box',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          flexShrink: 0,
          ...AppTypography.cormorantBold,
          fontSize: 20,
          lineHeight: lineHeight(20),
          color: hue,
        }}
      >
        {sub.name === '' ? '✨' : sub.name[0].toUpperCase()}
      </div>
      <div style={{ width: 14 }} />
      <div style={{ flex: 1, minWidth: 0, display: 'flex', flexDirection: 'column' }}>
        <span className="ellipsis" style={{ ...AppTypography.outfitBold, fontSize: 15, lineHeight: lineHeight(15), color: AppColors.petalWhite }}>
          {sub.name === '' ? 'Unnamed' : sub.name}
        </span>
        <div style={{ height: 3 }} />
        <div style={{ display: 'flex', alignItems: 'center' }}>
          <span style={{ ...AppTypography.outfitBold, fontSize: 12, lineHeight: mixedLineHeight(12), color: AppColors.blushGold }}>
            {`${formatPeso(sub.price)}${cycleSuffix(sub)}`}
          </span>
          <div style={{ width: 8 }} />
          <div
            style={{
              padding: '2px 8px',
              background: withAlpha(hue, 0.12),
              borderRadius: AppRadius.full,
              border: `1px solid ${withAlpha(hue, 0.35)}`,
              display: 'flex',
              ...AppTypography.outfitBold,
              fontSize: 10,
              lineHeight: lineHeight(10),
              color: hue,
            }}
          >
            {payerName(sub.payer)}
          </div>
        </div>
      </div>
      <div style={{ width: 10 }} />
      <RenewalPill days={days} />
    </div>
  );
}

function RenewalPill({ days }: { days: number }) {
  const urgent = days <= 3;
  const soon = days <= 7;
  const color = urgent ? AppColors.error : soon ? AppColors.warmAmber : withAlpha(AppColors.petalWhite, 0.65);
  const tint = (a: number) => withAlpha(urgent || soon ? color : AppColors.petalWhite, a);
  return (
    <div
      style={{
        padding: '7px 10px',
        background: tint(0.1),
        borderRadius: AppRadius.full,
        border: `1px solid ${tint(0.35)}`,
        display: 'flex',
        alignItems: 'center',
        flexShrink: 0,
      }}
    >
      <Icon name={urgent ? 'alarm' : 'refresh'} size={12} color={color} />
      <div style={{ width: 5 }} />
      <span style={{ ...AppTypography.outfitBold, fontSize: 11, lineHeight: lineHeight(11), color }}>{renewalLabel(days)}</span>
    </div>
  );
}
