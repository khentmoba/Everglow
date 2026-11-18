// Port of lib/shared/widgets/everglow/everglow_app_bar.dart.
import type { ReactNode } from 'react';
import { useNavigate } from 'react-router';
import { AppTypography } from '../../core/theme/typography';
import { EverglowIconButton } from './EverglowScaffold';
import { canPop } from './MaterialFields';

export function EverglowAppBar({
  title,
  titleWidget,
  showBack = true,
  onBackPressed,
  actions = [],
  height = 56,
}: {
  title?: string;
  titleWidget?: ReactNode;
  showBack?: boolean;
  onBackPressed?: () => void;
  actions?: ReactNode[];
  height?: number;
}) {
  const navigate = useNavigate();
  const back = onBackPressed ?? (() => (canPop() ? navigate(-1) : navigate('/dashboard')));
  return (
    <div style={{ height, boxSizing: 'border-box', padding: '8px 16px', display: 'flex', alignItems: 'center', flexShrink: 0 }}>
      {showBack && (
        // The 44px button is squeezed to the 40px row height: a 40px circle in a 44px-wide slot.
        <div
          style={{
            width: 44,
            height: height - 16,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            flexShrink: 0,
          }}
        >
          <EverglowIconButton
            icon="arrow_back_ios_new"
            semanticLabel="Go back"
            tooltip="Back"
            size={height - 16}
            onPressed={back}
          />
        </div>
      )}
      {title != null || titleWidget != null ? (
        <>
          <div style={{ width: 12 }} />
          <div style={{ flex: 1, minWidth: 0 }}>
            {titleWidget ?? (
              <div style={{ ...AppTypography.titleMedium, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                {title}
              </div>
            )}
          </div>
        </>
      ) : (
        <div style={{ flex: 1 }} />
      )}
      {actions.map((a, i) => (
        <div key={i} style={{ paddingLeft: 8 }}>
          {a}
        </div>
      ))}
    </div>
  );
}
