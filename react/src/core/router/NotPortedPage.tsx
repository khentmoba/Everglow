// Placeholder for screens still on Flutter. Only reachable in this
// in-progress React build, never on the live site.
import { useLocation, useNavigate } from 'react-router';
import { AppColors, withAlpha } from '../theme/colors';

export function NotPortedPage() {
  const location = useLocation();
  const navigate = useNavigate();
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
        gap: 12,
        padding: 24,
        textAlign: 'center',
      }}
    >
      <span style={{ fontSize: 16, fontWeight: 600 }}>{location.pathname}</span>
      <span style={{ fontSize: 13, color: withAlpha(AppColors.petalWhite, 0.6) }}>
        This screen hasn&apos;t moved to React yet.
      </span>
      <button
        type="button"
        className="bare-button"
        onClick={() => navigate('/')}
        style={{ padding: '8px 16px', borderRadius: 20, background: AppColors.deepRose, fontSize: 13 }}
      >
        Back to the door
      </button>
    </div>
  );
}
