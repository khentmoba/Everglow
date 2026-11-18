import type { ReactNode } from 'react';
import { useNavigate } from 'react-router';
import { useViewport } from '../../core/system/viewport';
import { AppColors, withAlpha } from '../../core/theme/colors';
import { AppTypography } from '../../core/theme/typography';
import { HueGlyph } from './HueGlyph';
import { Icon } from './Icon';
import { canPop } from './MaterialFields';
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
  const titleSize = width < 360 ? 22 : 26;
  const hPad = width < 360 ? 12 : 16;

  return (
    <div style={{ padding: `14px ${hPad}px 8px` }}>
      <div style={{ display: 'flex', alignItems: 'center', minHeight: 48 }}>
        {showBack && (
          <>
            <Tooltip message="Back">
              <button
                type="button"
                className="bare-button"
                aria-label="Back"
                onClick={onBack ?? (() => (canPop() ? navigate(-1) : navigate('/dashboard')))}
                style={{
                  width: 44,
                  height: 44,
                  borderRadius: '50%',
                  background: withAlpha(AppColors.moonlight, 0.07),
                  boxShadow: `inset 0 0 0 1px ${withAlpha(AppColors.moonlight, 0.12)}`,
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  flexShrink: 0,
                }}
              >
                <Icon name="arrow_back_ios_new" size={16} color={AppColors.roseQuartz} />
              </button>
            </Tooltip>
            <div style={{ width: 12 }} />
          </>
        )}
        {icon && (
          <>
            <HueGlyph icon={icon} hue={hue} size={40} iconSize={19} />
            <div style={{ width: 12 }} />
          </>
        )}
        <div style={{ flex: 1, minWidth: 0, display: 'flex', flexDirection: 'column', alignItems: 'flex-start' }}>
          <h1
            style={{
              margin: 0,
              ...AppTypography.cormorantBoldWhite,
              fontSize: titleSize,
              lineHeight: 1.05,
              letterSpacing: -0.2,
              whiteSpace: 'nowrap',
              overflow: 'hidden',
              textOverflow: 'ellipsis',
              maxWidth: '100%',
            }}
          >
            {title}
          </h1>
          {subtitle && (
            <span
              style={{
                ...AppTypography.handwrittenBody,
                fontSize: 17,
                lineHeight: 1.15,
                color: withAlpha(AppColors.blushGold, 0.88),
                whiteSpace: 'nowrap',
                overflow: 'hidden',
                textOverflow: 'ellipsis',
                maxWidth: '100%',
              }}
            >
              {subtitle}
            </span>
          )}
        </div>
        {actions.map((a, i) => (
          <div key={i} style={{ paddingLeft: 8 }}>
            {a}
          </div>
        ))}
      </div>
      <div
        aria-hidden
        style={{
          height: 1,
          marginTop: 12,
          background: `linear-gradient(90deg, ${withAlpha(hue, 0.45)}, ${withAlpha(AppColors.moonlight, 0.08)} 45%, transparent)`,
        }}
      />
    </div>
  );
}
