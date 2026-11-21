// Port of lib/shared/widgets/partner_presence_indicator.dart.
import { useEffect, useState } from 'react';
import { doc, onSnapshot, type DocumentData, type DocumentSnapshot, type Timestamp } from 'firebase/firestore';
import { AgentMode } from '../../core/agent/agentMode';
import { useAuth } from '../../core/services/auth';
import { db } from '../../core/services/firebase';
import { AppColors, withAlpha } from '../../core/theme/colors';
import { AppTypography } from '../../core/theme/typography';
import { snapshots, just, type Source } from '../../core/utils/liveSource';
import { useSource } from '../../core/utils/liveSource';

type PresenceData = {
  isOnline: boolean;
  lastSeen?: Date;
};

function watchPartnerPresence(partnerUid: string): Source<PresenceData> {
  if (AgentMode.demo) {
    return just({ isOnline: false, lastSeen: undefined });
  }
  const ref = doc(db, 'presence', partnerUid);
  return snapshots<DocumentSnapshot<DocumentData>, PresenceData>(
    (next, err) => onSnapshot(ref, next, err),
    (snap) => {
      if (!snap.exists()) return { isOnline: false };
      const data = snap.data() ?? {};
      const ls = data.lastSeen as Timestamp | undefined;
      const lastSeen = ls && typeof ls.toDate === 'function' ? ls.toDate() : undefined;
      return {
        isOnline: Boolean(data.isOnline),
        lastSeen,
      };
    },
  );
}

function formatAgo(ms: number): string {
  const mins = Math.floor(ms / 60_000);
  if (mins < 1) return 'just now';
  if (mins < 60) return `${mins}m`;
  const hrs = Math.floor(mins / 60);
  if (hrs < 24) return `${hrs}h`;
  return `${Math.floor(hrs / 24)}d`;
}

export function PartnerPresenceIndicator({
  dotSize = 8,
  fontSize = 10,
}: {
  dotSize?: number;
  fontSize?: number;
}) {
  const auth = useAuth();
  const [now, setNow] = useState(() => Date.now());
  const partnerUid = auth.partnerUid;
  const partnerName = auth.partnerName;

  useEffect(() => {
    let id = 0;
    const sync = () => setNow(Date.now());
    const start = () => {
      if (id || document.hidden) return;
      id = window.setInterval(sync, 30_000);
    };
    const stop = () => {
      if (!id) return;
      clearInterval(id);
      id = 0;
    };
    const onVis = () => {
      if (document.hidden) {
        stop();
      } else {
        sync();
        start();
      }
    };
    start();
    document.addEventListener('visibilitychange', onVis);
    return () => {
      stop();
      document.removeEventListener('visibilitychange', onVis);
    };
  }, []);

  const presence = useSource<PresenceData>(
    () => (partnerUid ? watchPartnerPresence(partnerUid) : just({ isOnline: false })),
    [partnerUid],
    { isOnline: false },
  );

  if (!auth.isCoupleUser) return null;

  if (!partnerUid) {
    return (
      <span
        style={{
          ...AppTypography.outfitWhite,
          fontSize,
          color: withAlpha(AppColors.roseQuartz, 0.5),
          fontWeight: 400,
        }}
      >
        {partnerName} · linking...
      </span>
    );
  }

  const freshOnline =
    presence.isOnline &&
    (!presence.lastSeen || now - presence.lastSeen.getTime() < 5 * 60_000);

  if (freshOnline) {
    return (
      <span style={{ display: 'inline-flex', alignItems: 'center', gap: 6 }}>
        <span
          style={{
            width: dotSize,
            height: dotSize,
            borderRadius: '50%',
            background: AppColors.success,
            boxShadow: `0 0 6px ${withAlpha(AppColors.success, 0.7)}`,
          }}
        />
        <span
          style={{
            ...AppTypography.outfitWhite,
            fontSize,
            color: AppColors.success,
            fontWeight: 500,
          }}
        >
          {partnerName} is active
        </span>
      </span>
    );
  }

  if (!presence.lastSeen) {
    return (
      <span
        style={{
          ...AppTypography.outfitWhite,
          fontSize,
          color: withAlpha(AppColors.roseQuartz, 0.5),
          fontWeight: 400,
        }}
      >
        {partnerName} · not online yet
      </span>
    );
  }

  return (
    <span style={{ display: 'inline-flex', alignItems: 'center', gap: 6 }}>
      <span
        style={{
          width: dotSize,
          height: dotSize,
          borderRadius: '50%',
          background: withAlpha(AppColors.roseQuartz, 0.6),
        }}
      />
      <span
        style={{
          ...AppTypography.outfitWhite,
          fontSize,
          color: withAlpha(AppColors.roseQuartz, 0.85),
          fontWeight: 500,
        }}
      >
        Active {formatAgo(now - presence.lastSeen.getTime())} ago
      </span>
    </span>
  );
}
