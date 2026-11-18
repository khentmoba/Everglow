// Port of tt_multiplayer_lobby_screen.dart and tt_multiplayer_game_screen_web.dart.
// The game replaces the lobby in place (Flutter's pushReplacement keeps the URL).
import { useEffect, useRef, useState } from 'react';
import { useAuth } from '../../../core/services/auth';
import { AppColors, withAlpha } from '../../../core/theme/colors';
import { boxShadow, letterSpacing } from '../../../core/theme/paint';
import { AppTypography } from '../../../core/theme/typography';
import { CircularProgress } from '../../../shared/widgets/CircularProgress';
import { TextButton } from '../../../shared/widgets/Dialogs';
import { Icon } from '../../../shared/widgets/Icon';
import { overlayTop, RotateBlock, TTGameFrame, useMobilePortraitBlocked, usePlayZoneBack, WebOverlayButton } from './TTFrame';
import { handleTTMessage, TTBridge, ttService } from './ttService';

export function TTLobbyPage() {
  const [game, setGame] = useState<{ roomId: string; isHost: boolean } | null>(null);
  if (game) return <TTMultiplayerGame roomId={game.roomId} isHost={game.isHost} />;
  return <Lobby onStart={setGame} />;
}

function Lobby({ onStart }: { onStart: (g: { roomId: string; isHost: boolean }) => void }) {
  const auth = useAuth();
  const [searching, setSearching] = useState(false);
  const [roomId, setRoomId] = useState<string | null>(null);
  const [statusText, setStatusText] = useState<string | null>(null);
  const [countdown, setCountdown] = useState(0);
  const mounted = useRef(true);
  const guestSub = useRef<(() => void) | null>(null);

  useEffect(() => {
    mounted.current = true;
    return () => {
      mounted.current = false;
      guestSub.current?.();
    };
  }, []);

  const startCountdown = (id: string, isHost: boolean) => {
    setRoomId(id);
    setCountdown(3);
    setSearching(false);
    let left = 3;
    const step = () => {
      window.setTimeout(() => {
        if (!mounted.current) return;
        if (left > 1) {
          left--;
          setCountdown(left);
          return step();
        }
        setCountdown(0);
        onStart({ roomId: id, isHost });
      }, 1000);
    };
    step();
  };

  const waitForGuest = (id: string) => {
    guestSub.current?.();
    guestSub.current = ttService.watchRoom(id)({
      data: (room) => {
        if (mounted.current && room.guestUid != null) startCountdown(id, true);
      },
    });
  };

  const findMatch = async () => {
    const uid = auth.uid;
    if (!uid) return;
    setSearching(true);
    setStatusText('Searching for opponent...');
    try {
      const existing = await ttService.findOpenRoom(uid);
      if (!mounted.current) return;
      if (existing) {
        await ttService.joinRoom(existing.id, uid);
        if (!mounted.current) return;
        startCountdown(existing.id, false);
      } else {
        const room = await ttService.createRoom(uid);
        if (!mounted.current) return;
        waitForGuest(room.id);
      }
    } catch (e) {
      if (!mounted.current) return;
      setSearching(false);
      setStatusText(`Error: ${e instanceof Error ? e.message : String(e)}`);
    }
  };

  const cancelSearch = () => {
    guestSub.current?.();
    guestSub.current = null;
    if (roomId != null) void ttService.deleteRoom(roomId).catch(() => {});
    setSearching(false);
    setRoomId(null);
    setStatusText(null);
  };

  return (
    <div
      style={{
        position: 'fixed',
        inset: 0,
        background: '#000',
        padding:
          'env(safe-area-inset-top, 0px) env(safe-area-inset-right, 0px) env(safe-area-inset-bottom, 0px) env(safe-area-inset-left, 0px)',
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        justifyContent: 'center',
        overflow: 'hidden',
      }}
    >
      <Icon name="sports_tennis" size={64} color={AppColors.warmAmber} />
      <div style={{ height: 16 }} />
      <span style={{ ...AppTypography.cormorantBold, fontSize: 32 }}>Table Tennis 1v1</span>
      <div style={{ height: 8 }} />
      <span style={{ ...AppTypography.outfitWhite, fontSize: 14, color: withAlpha(AppColors.petalWhite, 0.75) }}>
        Play against your partner
      </span>
      <div style={{ height: 48 }} />
      {!searching && countdown === 0 && (
        <button
          type="button"
          className="bare-button"
          onClick={() => void findMatch()}
          style={{
            padding: '16px 48px',
            borderRadius: 24,
            background: `linear-gradient(90deg, ${AppColors.warmAmber}, ${AppColors.deepRose})`,
            boxShadow: boxShadow([{ blur: 10, offset: [0, 4], color: 'rgba(245, 166, 35, 0.3)' }]),
            cursor: 'pointer',
          }}
        >
          <span style={{ ...AppTypography.outfitWhite, fontWeight: 900, fontSize: 16, display: 'block', ...letterSpacing(2) }}>
            Find Match
          </span>
        </button>
      )}
      {searching && (
        <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
          <CircularProgress size={48} strokeWidth={3} color={AppColors.warmAmber} />
          <div style={{ height: 16 }} />
          <span style={{ ...AppTypography.outfitWhite, fontSize: 16 }}>{statusText ?? 'Searching for opponent...'}</span>
          <div style={{ height: 8 }} />
          <div style={{ display: 'flex' }}>
            {[0, 1, 2].map((i) => (
              <div
                key={i}
                style={{
                  width: 8,
                  height: 8,
                  margin: '0 4px',
                  borderRadius: '50%',
                  background: AppColors.warmAmber,
                  animation: `tt-dot-in ${600 + i * 200}ms linear both`,
                }}
              />
            ))}
          </div>
          <style>{'@keyframes tt-dot-in { from { opacity: 0 } to { opacity: 1 } }'}</style>
          <div style={{ height: 24 }} />
          <TextButton onPressed={cancelSearch} color={withAlpha(AppColors.petalWhite, 0.7)} style={{ fontWeight: 500 }}>
            Cancel
          </TextButton>
        </div>
      )}
      {countdown > 0 && (
        <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
          <span style={{ ...AppTypography.outfitBold, fontSize: 20, color: AppColors.warmAmber }}>Match found!</span>
          <div style={{ height: 16 }} />
          <span style={{ ...AppTypography.cormorantBold, fontSize: 72 }}>{countdown}</span>
        </div>
      )}
      <div style={{ height: 32 }} />
      {roomId != null && (
        <span style={{ ...AppTypography.outfitWhite, fontSize: 12, color: withAlpha(AppColors.petalWhite, 0.55) }}>
          Room: {roomId}
        </span>
      )}
    </div>
  );
}

function TTMultiplayerGame({ roomId, isHost }: { roomId: string; isHost: boolean }) {
  const auth = useAuth();
  const back = usePlayZoneBack();
  const blocked = useMobilePortraitBlocked();
  const bridge = useRef<TTBridge | null>(null);

  useEffect(() => {
    window.addEventListener('message', handleTTMessage);
    const frame = requestAnimationFrame(() => {
      if (!auth.uid) return;
      bridge.current = new TTBridge();
      bridge.current.connect(roomId, isHost);
    });
    return () => {
      cancelAnimationFrame(frame);
      window.removeEventListener('message', handleTTMessage);
      bridge.current?.disconnect();
      bridge.current = null;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [roomId, isHost]);

  const close = () => {
    bridge.current?.disconnect();
    back();
  };

  return (
    <div style={{ position: 'fixed', inset: 0, background: '#000' }}>
      <TTGameFrame src="/table_tennis/assets/index.typed.html?v=1&mode=mp" />
      <div style={{ ...overlayTop, left: 12 }}>
        <WebOverlayButton icon="close" onTap={close} />
      </div>
      {blocked && <RotateBlock onBack={close} />}
    </div>
  );
}
