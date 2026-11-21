import { useEffect, useState } from 'react';
import { useLocation, useNavigate } from 'react-router';
import { AgentMode } from '../../core/agent/agentMode';
import { useAuth } from '../../core/services/auth';
import { AppColors, Derived, withAlpha } from '../../core/theme/colors';
import { AppTypography } from '../../core/theme/typography';
import { useSource } from '../../core/utils/liveSource';
import { Icon } from '../../shared/widgets/Icon';
import { isRoomLive, roomsStream, type WatchPartyRoom } from './watchPartyService';

export function IncomingWatchPartyBanner() {
  const auth = useAuth();
  const location = useLocation();
  const navigate = useNavigate();
  const myUid = auth.uid ?? '';
  const enabled = !AgentMode.demo && auth.isReady && auth.isCoupleUser && myUid.length > 0;
  const rooms = useSource(() => (enabled ? roomsStream(myUid) : null), [enabled, myUid], []);
  const [dismissedIds, setDismissedIds] = useState<Record<string, number>>({});

  const livePartnerRoom: WatchPartyRoom | null =
    rooms.find((r) => {
      if (!isRoomLive(r, 10)) return false;
      if (r.updatedBy === myUid) return false;
      const updatedMs = r.updatedAt?.getTime() ?? 0;
      const dismissedAt = dismissedIds[r.id] ?? 0;
      if (dismissedAt > 0 && updatedMs <= dismissedAt) return false;
      return true;
    }) ?? null;

  useEffect(() => {
    if (location.pathname.startsWith('/watch-party') && livePartnerRoom) {
      setDismissedIds((prev) => ({ ...prev, [livePartnerRoom.id]: Date.now() }));
    }
  }, [location.pathname, livePartnerRoom]);

  if (!livePartnerRoom || location.pathname.startsWith('/watch-party')) return null;

  return (
    <div
      role="region"
      aria-label="Incoming Watch Party invitation"
      style={{
        position: 'fixed',
        top: 'calc(env(safe-area-inset-top, 0px) + 14px)',
        left: '50%',
        transform: 'translateX(-50%)',
        zIndex: 1300,
        width: 'min(92vw, 420px)',
        padding: '10px 12px',
        borderRadius: 16,
        background: withAlpha(AppColors.plum, 0.96),
        border: `1px solid ${withAlpha(AppColors.deepRose, 0.65)}`,
        boxShadow: '0 10px 30px rgba(0, 0, 0, 0.5)',
        display: 'flex',
        alignItems: 'center',
        gap: 10,
      }}
    >
      <div
        style={{
          width: 36,
          height: 36,
          borderRadius: 10,
          background: withAlpha(AppColors.deepRose, 0.25),
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          flexShrink: 0,
        }}
      >
        <Icon name="live_tv" size={20} color={AppColors.roseQuartz} />
      </div>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div
          style={{
            ...AppTypography.outfitBold,
            fontSize: 12.5,
            color: AppColors.petalWhite,
            whiteSpace: 'nowrap',
            overflow: 'hidden',
            textOverflow: 'ellipsis',
          }}
        >
          {auth.partnerName} is in {livePartnerRoom.name || 'Watch Together'}
        </div>
        <div
          style={{
            fontSize: 11.5,
            color: Derived.textMedium,
            whiteSpace: 'nowrap',
            overflow: 'hidden',
            textOverflow: 'ellipsis',
          }}
        >
          {livePartnerRoom.title || 'Waiting to pick a title'}
        </div>
      </div>
      <button
        type="button"
        className="bare-button"
        onClick={() => {
          setDismissedIds((prev) => ({ ...prev, [livePartnerRoom.id]: Date.now() }));
          navigate(`/watch-party?room=${encodeURIComponent(livePartnerRoom.id)}`);
        }}
        style={{
          padding: '7px 12px',
          borderRadius: 999,
          background: AppColors.deepRose,
          color: AppColors.petalWhite,
          ...AppTypography.outfitBold,
          fontSize: 12,
          flexShrink: 0,
        }}
      >
        Join
      </button>
      <button
        type="button"
        className="bare-button"
        aria-label="Dismiss watch party banner"
        onClick={() => setDismissedIds((prev) => ({ ...prev, [livePartnerRoom.id]: Date.now() }))}
        style={{ padding: 4 }}
      >
        <Icon name="close" size={16} color={Derived.textMuted} />
      </button>
    </div>
  );
}
