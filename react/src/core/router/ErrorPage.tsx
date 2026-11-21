// Port of lib/core/router/app_error_page.dart.
import { useLocation, useNavigate } from 'react-router';
import { useAuth } from '../services/auth';
import { AppColors, withAlpha } from '../theme/colors';
import { lineHeight } from '../theme/paint';
import { AppTypography } from '../theme/typography';
import { ElevatedButton } from '../../shared/widgets/ElevatedButton';
import { Icon } from '../../shared/widgets/Icon';

export function homeRouteFor(isAuthenticated: boolean, isCinemaOnlyUser: boolean): string {
  if (!isAuthenticated) return '/';
  return isCinemaOnlyUser ? '/cinema' : '/dashboard';
}

export function ErrorPage({ uri }: { uri?: string }) {
  const location = useLocation();
  const navigate = useNavigate();
  const auth = useAuth();
  const displayUri = uri ?? `${location.pathname}${location.search}${location.hash}`;

  const handleGoHome = () => {
    navigate(homeRouteFor(auth.hasActiveSession, auth.isCinemaOnlyUser));
  };

  return (
    <div
      style={{
        position: 'fixed',
        inset: 0,
        background: AppColors.inkDeep,
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        justifyContent: 'center',
      }}
    >
      <Icon name="cloud_off" variant="outlined" size={64} color={AppColors.petalWhite} />
      <div style={{ height: 24 }} />
      <div style={{ ...AppTypography.cormorantBlack, fontSize: 28, color: AppColors.petalWhite }}>Page not found</div>
      <div style={{ height: 8 }} />
      <div
        style={{
          ...AppTypography.outfitWhite,
          fontSize: 14,
          color: withAlpha(AppColors.petalWhite, 0.6),
        }}
      >
        {displayUri}
      </div>
      <div style={{ height: 24 }} />
      <ElevatedButton onPressed={handleGoHome}>
        <span style={{ ...AppTypography.labelLarge, lineHeight: lineHeight(14, 1.26) }}>Go home</span>
      </ElevatedButton>
    </div>
  );
}
