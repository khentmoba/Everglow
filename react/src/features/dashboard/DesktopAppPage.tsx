// Port of lib/features/dashboard/presentation/screens/desktop_app_screen.dart
// and lib/shared/widgets/everglow/desktop_app_action.dart.
import { useState } from 'react';
import { useNavigate } from 'react-router';
import { AppColors, Derived } from '../../core/theme/colors';
import { AppSpacing } from '../../core/theme/layout';
import { AppTypography } from '../../core/theme/typography';
import { EverglowBackground } from '../../shared/widgets/EverglowBackground';
import { Icon } from '../../shared/widgets/Icon';

const DOWNLOAD_URL = 'https://github.com/khentmoba/Everglow-Desktop/releases/latest/download/Everglow-Desktop-Setup.exe';
const RELEASES_URL = 'https://github.com/khentmoba/Everglow-Desktop/releases/latest';

interface DesktopBridge {
  version?: string;
  checkForUpdates?: () => void;
}

function getDesktopBridge(): DesktopBridge | null {
  const w = window as unknown as { everglowDesktop?: DesktopBridge };
  return w.everglowDesktop ?? null;
}

export function DesktopAppPage() {
  const navigate = useNavigate();
  const [error, setError] = useState<string | null>(null);
  const bridge = getDesktopBridge();
  const version = bridge?.version ?? null;
  const isWindows = typeof navigator !== 'undefined' && /Windows/i.test(navigator.userAgent);

  const handleActivate = () => {
    setError(null);
    try {
      if (version && bridge?.checkForUpdates) {
        bridge.checkForUpdates();
      } else {
        window.open(isWindows ? DOWNLOAD_URL : RELEASES_URL, '_blank', 'noopener,noreferrer');
      }
    } catch {
      setError('Could not open it. Please try again.');
    }
  };

  return (
    <div style={{ position: 'fixed', inset: 0, display: 'flex', flexDirection: 'column', background: AppColors.twilight }}>
      <EverglowBackground baseColor={AppColors.twilight} />
      <div
        style={{
          position: 'relative',
          width: '100%',
          height: '100%',
          display: 'flex',
          flexDirection: 'column',
        }}
      >
        <header
          style={{
            height: 56,
            padding: `${AppSpacing.sm}px ${AppSpacing.lg}px`,
            display: 'flex',
            alignItems: 'center',
            gap: AppSpacing.md,
          }}
        >
          <button
            type="button"
            className="bare-button"
            aria-label="Go back"
            onClick={() => (window.history.length > 1 ? navigate(-1) : navigate('/dashboard'))}
            style={{
              width: 44,
              height: 44,
              borderRadius: '50%',
              background: Derived.surfaceGlass,
              border: `1px solid ${Derived.border}`,
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
            }}
          >
            <Icon name="arrow_back_ios_new" size={18} color={AppColors.roseQuartz} />
          </button>
          <h1 style={{ margin: 0, ...AppTypography.titleMedium }}>Desktop App</h1>
        </header>

        <div
          style={{
            flex: 1,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            overflowY: 'auto',
          }}
        >
          <div
            style={{
              width: '100%',
              maxWidth: 560,
              padding: AppSpacing.lg,
              display: 'flex',
              flexDirection: 'column',
              alignItems: 'center',
            }}
          >
            <Icon name="desktop_windows" size={48} color={AppColors.blushGold} />
            <div style={{ height: AppSpacing.x2 }} />
            <div style={{ ...AppTypography.cormorantBold, fontSize: 28, textAlign: 'center' }}>
              Everglow for Windows
            </div>
            <div style={{ height: AppSpacing.md }} />
            <div
              style={{
                ...AppTypography.bodyMedium,
                textAlign: 'center',
              }}
            >
              Download the desktop app or check for updates here whenever you need them.
            </div>
            <div style={{ height: AppSpacing.x2 }} />
            <button
              type="button"
              className="bare-button"
              onClick={handleActivate}
              style={{
                minHeight: 48,
                padding: '0 16px',
                display: 'inline-flex',
                alignItems: 'center',
                gap: 8,
                color: AppColors.blushGold,
                ...AppTypography.labelLarge,
              }}
            >
              <Icon name={version == null ? 'download' : 'system_update_alt'} size={18} color={AppColors.blushGold} />
              <span style={{ color: AppColors.blushGold }}>
                {version != null
                  ? 'Check for desktop updates'
                  : isWindows
                    ? 'Download for Windows'
                    : 'Everglow for Windows'}
              </span>
            </button>
            <div style={{ color: AppColors.petalWhite, fontSize: 12, textAlign: 'center' }}>
              {error ??
                (version == null
                  ? 'Already installed? Use Everglow → Check for Updates.'
                  : `Everglow Desktop ${version}`)}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
