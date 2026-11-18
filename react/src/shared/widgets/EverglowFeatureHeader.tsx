// Port of lib/shared/widgets/everglow/everglow_feature_header.dart.
import type { ReactNode } from 'react';
import { useNavigate } from 'react-router';
import { useViewport } from '../../core/system/viewport';
import { AppColors, Derived, withAlpha } from '../../core/theme/colors';
import { AppRadius } from '../../core/theme/layout';
import { AppTypography } from '../../core/theme/typography';
import { Icon } from './Icon';
import { Tooltip } from './Tooltip';

export function EverglowFeatureHeader({
  title,
  subtitle,
  icon,
  hue = AppColors.blushGold,
  onBack,
  actions = [],
  showBack = true,
}: {
  title: string;
  subtitle?: string;
  icon?: string;
  hue?: string;
  onBack?: () => void;
  actions?: ReactNode[];
  showBack?: boolean;
}) {
  const navigate = useNavigate();
  const { width } = useViewport();
  const titleSize = width < 360 ? 18 : 21;
  const hPad = width < 360 ? 12 : 16;

  return (
    <div style={{ padding: `12px ${hPad}px 10px` }}>
      <div
        style={{
          padding: '11px 12px',
          background: Derived.panelGlass,
          borderRadius: AppRadius.xl,
          border: `1px solid ${withAlpha(AppColors.moonlight, 0.11)}`,
          boxShadow: `0 6px 8px ${withAlpha(AppColors.inkDeep, 0.2)}`,
          display: 'flex',
          alignItems: 'center',
        }}
      >
        {showBack && (
          <>
            <Tooltip message="Back">
              <button
                type="button"
                className="bare-button"
                aria-label="Back"
                onClick={onBack ?? (() => (window.history.length > 1 ? navigate(-1) : navigate('/dashboard')))}
                style={{
                  width: 44,
                  height: 44,
                  borderRadius: '50%',
                  background: withAlpha(AppColors.moonlight, 0.08),
                  border: `1px solid ${withAlpha(AppColors.moonlight, 0.16)}`,
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  flexShrink: 0,
                }}
              >
                <Icon name="arrow_back_ios_new" size={16} color={AppColors.roseQuartz} />
              </button>
            </Tooltip>
            <div style={{ width: 10 }} />
          </>
        )}
        {icon && (
          <>
            <div
              style={{
                width: 40,
                height: 40,
                borderRadius: '50%',
                background: withAlpha(hue, 0.13),
                border: `1px solid ${withAlpha(hue, 0.34)}`,
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                flexShrink: 0,
              }}
            >
              <Icon name={icon} size={18} color={hue} />
            </div>
            <div style={{ width: 10 }} />
          </>
        )}
        <div style={{ flex: 1, minWidth: 0, display: 'flex', flexDirection: 'column', alignItems: 'flex-start' }}>
          <h1
            style={{
              margin: 0,
              ...AppTypography.cormorantBold,
              fontSize: titleSize,
              lineHeight: 1,
              letterSpacing: 0.3,
              color: AppColors.petalWhite,
              whiteSpace: 'nowrap',
              overflow: 'hidden',
              textOverflow: 'ellipsis',
              maxWidth: '100%',
            }}
          >
            {title}
          </h1>
          {subtitle && (
            <>
              <div style={{ height: 2 }} />
              <span
                style={{
                  ...AppTypography.outfitWhite,
                  fontSize: 11,
                  fontWeight: 500,
                  color: Derived.textMedium,
                  letterSpacing: 0.35,
                  whiteSpace: 'nowrap',
                  overflow: 'hidden',
                  textOverflow: 'ellipsis',
                  maxWidth: '100%',
                }}
              >
                {subtitle}
              </span>
            </>
          )}
        </div>
        {actions.map((a, i) => (
          <div key={i} style={{ paddingLeft: 6 }}>
            {a}
          </div>
        ))}
      </div>
    </div>
  );
}
