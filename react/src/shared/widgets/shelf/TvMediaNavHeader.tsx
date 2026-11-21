import { useNavigate } from 'react-router';
import { useAuth } from '../../../core/services/auth';
import { useValue } from '../../../core/system/store';
import { TvMode } from '../../../core/system/tvMode';
import { AppColors, Derived, withAlpha } from '../../../core/theme/colors';
import { AppTypography } from '../../../core/theme/typography';
import { Icon } from '../Icon';

const MEDIA_SECTIONS = [
  { route: '/cinema', label: 'Cinema', icon: 'movie', accent: AppColors.auroraGold },
  { route: '/anime', label: 'Anime', icon: 'animation', accent: AppColors.auroraRose },
  { route: '/manga', label: 'MangaCelestia', icon: 'auto_stories', accent: AppColors.roseQuartz },
] as const;

export function TvMediaNavHeader({
  currentRoute,
  onLogout,
}: {
  currentRoute: string;
  onLogout?: () => void;
}) {
  const isTv = useValue(TvMode.isTvMode);
  const auth = useAuth();
  const navigate = useNavigate();

  if (!isTv) return null;

  return (
    <nav
      aria-label="TV Media Navigation"
      style={{
        width: '100%',
        padding: '10px 18px',
        background: withAlpha(AppColors.inkDeep, 0.95),
        borderBottom: `1px solid ${withAlpha(AppColors.moonlight, 0.18)}`,
        boxShadow: '0 4px 16px rgba(0, 0, 0, 0.45)',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'space-between',
        gap: 12,
        overflowX: 'auto',
        flexShrink: 0,
        zIndex: 60,
      }}
    >
      <div>
        {auth.isCoupleUser && (
          <button
            type="button"
            className="bare-button"
            onClick={() => navigate('/dashboard')}
            style={{
              padding: '8px 14px',
              borderRadius: 999,
              background: withAlpha(AppColors.auroraGold, 0.14),
              border: `1px solid ${withAlpha(AppColors.auroraGold, 0.35)}`,
              color: AppColors.petalWhite,
              ...AppTypography.outfitBold,
              fontSize: 13,
              display: 'inline-flex',
              alignItems: 'center',
              gap: 6,
            }}
          >
            <Icon name="home" size={18} color={AppColors.auroraGold} />
            <span>Dashboard</span>
          </button>
        )}
      </div>

      <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
        {MEDIA_SECTIONS.map((sec) => {
          const active = currentRoute === sec.route || currentRoute.startsWith(`${sec.route}/`);
          return (
            <button
              key={sec.route}
              type="button"
              className="bare-button"
              aria-current={active ? 'page' : undefined}
              onClick={() => {
                if (!active) navigate(sec.route);
              }}
              style={{
                padding: '9px 16px',
                borderRadius: 999,
                background: active ? withAlpha(sec.accent, 0.24) : withAlpha(AppColors.petalWhite, 0.05),
                border: `1.5px solid ${active ? sec.accent : Derived.border}`,
                color: AppColors.petalWhite,
                ...AppTypography.outfitBold,
                fontSize: 13.5,
                display: 'inline-flex',
                alignItems: 'center',
                gap: 8,
                whiteSpace: 'nowrap',
              }}
            >
              <Icon name={sec.icon} size={18} color={active ? sec.accent : Derived.textMedium} />
              <span>{sec.label}</span>
            </button>
          );
        })}
      </div>

      <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
        <button
          type="button"
          className="bare-button"
          onClick={() => TvMode.toggle()}
          title="Exit TV Mode"
          style={{
            padding: '7px 12px',
            borderRadius: 999,
            background: withAlpha(AppColors.auroraGold, 0.16),
            border: `1px solid ${withAlpha(AppColors.auroraGold, 0.45)}`,
            color: AppColors.auroraGold,
            ...AppTypography.outfitBold,
            fontSize: 12,
            display: 'inline-flex',
            alignItems: 'center',
            gap: 6,
          }}
        >
          <Icon name="tv" size={16} color={AppColors.auroraGold} />
          <span>TV Mode</span>
        </button>
        {onLogout && (
          <button
            type="button"
            className="bare-button"
            onClick={onLogout}
            style={{
              padding: '7px 12px',
              borderRadius: 999,
              background: withAlpha(AppColors.petalWhite, 0.08),
              border: `1px solid ${Derived.border}`,
              color: AppColors.petalWhite,
              ...AppTypography.outfitBold,
              fontSize: 12,
              display: 'inline-flex',
              alignItems: 'center',
              gap: 6,
            }}
          >
            <Icon name="logout" size={16} color={AppColors.petalWhite} />
            <span>Sign out</span>
          </button>
        )}
      </div>
    </nav>
  );
}
