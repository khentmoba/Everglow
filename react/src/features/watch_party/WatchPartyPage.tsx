// Port of lib/features/watch_party/presentation/screens/watch_party_lobby_screen.dart
// and watch_party_screen_web.dart.
import { useEffect, useMemo, useRef, useState } from 'react';
import { useNavigate, useSearchParams } from 'react-router';
import { displayNameFor, useAuth } from '../../core/services/auth';
import { useViewport } from '../../core/system/viewport';
import { AppColors, Derived, withAlpha } from '../../core/theme/colors';
import { AppRadius, AppSpacing } from '../../core/theme/layout';
import { Align, boxShadow, linear } from '../../core/theme/paint';
import { AppTypography } from '../../core/theme/typography';
import { useSource } from '../../core/utils/liveSource';
import { Icon } from '../../shared/widgets/Icon';
import { AlertDialog, TextButton, showDialog } from '../../shared/widgets/Dialogs';
import { showSnackBar } from '../../shared/widgets/SnackBar';
import { TmdbImages } from '../cinema/cinemaTypes';
import { MediaSectionMenuButton } from '../cinema/NetflixUi';
import {
  checkCommunityRoomMembership,
  communityRoomChatStream,
  communityRoomsStream,
  communityRoomStream,
  createCommunityWatchPartyRoom,
  deleteCommunityWatchPartyRoom,
  isCommunityRoomUnlocked,
  sendCommunityRoomChatMessage,
  unlockCommunityWatchPartyRoom,
  updateCommunityRoomMedia,
  updateCommunityWatchPartyRoom,
  type CommunityWatchPartyRoom,
} from './communityWatchPartyService';
import { HlsServerPlayer } from './HlsServerPlayer';
import { showEpisodePicker, showWatchPartyMediaPicker } from './WatchPartyPickerSheets';
import {
  createWatchPartyRoom,
  deleteWatchPartyRoom,
  formatPartyTime,
  isRoomLive,
  roomChatStream,
  roomStream,
  roomsStream,
  sendRoomChatMessage,
  updateRoomMedia,
  updateWatchPartyRoom,
  type WatchPartyChatMessage,
  type WatchPartyRoom,
} from './watchPartyService';
import {
  BUILTIN_WATCH_PARTY_SERVERS,
  cinesrcCommand,
  isUserSeek,
  parseCinesrcEvent,
  WatchPartyClock,
} from './watchPartySync';

function resolvePoster(path: string): string {
  if (!path) return '';
  if (path.startsWith('http') || path.startsWith('/')) return path;
  if (path.startsWith('assets/')) return `/${path.slice('assets/'.length)}`;
  return `${TmdbImages.poster}${path.startsWith('/') ? '' : '/'}${path}`;
}

export function WatchPartyPage() {
  const auth = useAuth();
  const navigate = useNavigate();
  const [params] = useSearchParams();
  const myUid = auth.uid ?? '';
  const activeRoomId = params.get('room');
  const scope = params.get('scope') === 'hub' ? 'hub' : 'private';
  const [hubTab, setHubTab] = useState<'hub' | 'couple'>('hub');

  if (activeRoomId) {
    return (
      <WatchPartyRoomView
        key={`${scope}:${activeRoomId}`}
        roomId={activeRoomId}
        scope={scope}
        myUid={myUid}
        myName={auth.currentUser ?? 'member'}
        isCoupleUser={auth.isCoupleUser}
        onExit={() => ((window.history.state?.idx ?? 0) > 0 ? navigate(-1) : navigate('/watch-party', { replace: true }))}
      />
    );
  }

  return (
    <div style={{ position: 'fixed', inset: 0, background: AppColors.inkDeep, display: 'flex', flexDirection: 'column' }}>
      <header
        style={{
          padding: '12px 16px',
          paddingTop: 'calc(12px + env(safe-area-inset-top))',
          background: withAlpha(AppColors.inkDeep, 0.96),
          borderBottom: `1px solid ${Derived.border}`,
          display: 'flex',
          alignItems: 'center',
          gap: 10,
          flexShrink: 0,
        }}
      >
        <button
          type="button"
          className="bare-button"
          aria-label="Back"
          onClick={() => ((window.history.state?.idx ?? 0) > 0 ? navigate(-1) : navigate(auth.isCoupleUser ? '/dashboard' : '/cinema'))}
          style={{
            width: 38,
            height: 38,
            borderRadius: '50%',
            background: withAlpha(AppColors.petalWhite, 0.07),
            border: `1px solid ${Derived.border}`,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
          }}
        >
          <Icon name="arrow_back" size={20} color={AppColors.petalWhite} />
        </button>

        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
            <Icon name="live_tv" size={18} color={AppColors.auroraRose} />
            <span style={{ ...AppTypography.outfitHeading, fontSize: 17, color: AppColors.petalWhite }}>
              Watch Party
            </span>
          </div>
          <div style={{ ...AppTypography.outfitWhite, fontSize: 12, color: Derived.textMuted }}>
            Cinema &amp; Anime · Synced on Everglow Server
          </div>
        </div>

        <button
          type="button"
          className="bare-button"
          aria-label="Open Global Chat"
          onClick={() => navigate('/global-chat')}
          style={{
            padding: '8px 12px',
            borderRadius: 999,
            background: withAlpha(AppColors.petalWhite, 0.07),
            border: `1px solid ${Derived.border}`,
            color: AppColors.petalWhite,
            ...AppTypography.outfitBold,
            fontSize: 12,
            display: 'inline-flex',
            alignItems: 'center',
            gap: 6,
          }}
        >
          <Icon name="forum" size={15} color={AppColors.blushGold} />
          <span>Chat</span>
        </button>

        <MediaSectionMenuButton currentRoute="/watch-party" />
      </header>

      <div
        className="no-scrollbar"
        style={{
          flex: 1,
          overflowY: 'auto',
          padding: `${AppSpacing.lg}px ${AppSpacing.xl}px ${AppSpacing.x3}px`,
          width: '100%',
          maxWidth: 780,
          margin: '0 auto',
          boxSizing: 'border-box',
        }}
      >
        {auth.isCoupleUser && (
          <div
            role="tablist"
            style={{
              display: 'grid',
              gridTemplateColumns: '1fr 1fr',
              gap: 6,
              padding: 4,
              borderRadius: AppRadius.sm,
              background: withAlpha(AppColors.shimmerBase, 0.72),
              border: `1px solid ${Derived.border}`,
              marginBottom: AppSpacing.md,
            }}
          >
            {(
              [
                ['hub', 'Watch Party Hub'],
                ['couple', 'Just Us Rooms'],
              ] as const
            ).map(([id, label]) => {
              const active = hubTab === id;
              return (
                <button
                  key={id}
                  role="tab"
                  aria-selected={active}
                  type="button"
                  className="bare-button"
                  onClick={() => setHubTab(id)}
                  style={{
                    padding: '8px 10px',
                    borderRadius: 10,
                    background: active ? withAlpha(AppColors.deepRose, 0.28) : 'transparent',
                    border: `1px solid ${active ? withAlpha(AppColors.blushGold, 0.45) : 'transparent'}`,
                    color: active ? AppColors.petalWhite : Derived.textMuted,
                    ...AppTypography.outfitBold,
                    fontSize: 12.5,
                  }}
                >
                  {label}
                </button>
              );
            })}
          </div>
        )}

        {auth.isCoupleUser && hubTab === 'couple' ? <WatchPartyLobby /> : <CommunityWatchPartyHub />}
      </div>
    </div>
  );
}

export function CommunityWatchPartyHub() {
  const auth = useAuth();
  const navigate = useNavigate();
  const myUid = auth.uid ?? '';
  const myUsername = auth.currentUser ?? '';
  const rooms = useSource(() => communityRoomsStream(), [], []);
  const [createOpen, setCreateOpen] = useState(false);
  const [roomName, setRoomName] = useState('');
  const [roomPassword, setRoomPassword] = useState('');
  const [creating, setCreating] = useState(false);
  const [joiningRoom, setJoiningRoom] = useState<CommunityWatchPartyRoom | null>(null);
  const [joinPassword, setJoinPassword] = useState('');
  const [joinError, setJoinError] = useState<string | null>(null);

  const openHubRoom = (roomId: string) => {
    navigate(`/watch-party?room=${encodeURIComponent(roomId)}&scope=hub`);
  };

  const handleCreate = async () => {
    if (!myUid || !myUsername || creating) return;
    setCreating(true);
    try {
      const created = await createCommunityWatchPartyRoom({
        hostUid: myUid,
        hostName: myUsername,
        name: roomName,
        password: roomPassword,
      });
      setCreateOpen(false);
      setRoomName('');
      setRoomPassword('');
      openHubRoom(created.id);
    } catch {
      showSnackBar('Could not create Watch Party room. Try again.');
    } finally {
      setCreating(false);
    }
  };

  const handleJoinClick = async (room: CommunityWatchPartyRoom) => {
    const canBypass =
      !room.hasPassword ||
      room.hostUid === myUid ||
      auth.isCoupleUser ||
      isCommunityRoomUnlocked(room.id) ||
      (await checkCommunityRoomMembership(room.id, myUid));
    if (!canBypass) {
      setJoiningRoom(room);
      setJoinPassword('');
      setJoinError(null);
      return;
    }
    if (!isRoomLive(room) && room.hostUid === myUid) {
      await updateCommunityWatchPartyRoom(room.id, { active: true, state: 'paused', updatedBy: myUid }).catch(() => {});
    }
    openHubRoom(room.id);
  };

  const handleVerifyPassword = async () => {
    if (!joiningRoom) return;
    const res = await unlockCommunityWatchPartyRoom(joiningRoom.id, joinPassword);
    if (!res.ok) {
      setJoinError(res.error || 'Incorrect room password.');
      return;
    }
    const targetId = joiningRoom.id;
    setJoiningRoom(null);
    setJoinPassword('');
    setJoinError(null);
    openHubRoom(targetId);
  };

  return (
    <>
      <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'stretch' }}>
        <div
          style={{
            marginBottom: AppSpacing.md,
            padding: '10px 14px',
            borderRadius: AppRadius.sm,
            background: withAlpha(AppColors.blushGold, 0.08),
            border: `1px solid ${withAlpha(AppColors.blushGold, 0.24)}`,
            display: 'flex',
            alignItems: 'center',
            gap: 10,
          }}
        >
          <Icon name="verified_user" size={18} color={AppColors.blushGold} />
          <div style={{ fontSize: 12.5, color: Derived.textMedium, lineHeight: 1.4 }}>
            Host a Cinema or Anime watch party, optionally add a password, or join any open room. All rooms run locked on{' '}
            <strong style={{ color: AppColors.petalWhite }}>Everglow Server</strong> for reliable sync.
          </div>
        </div>

        <button
          type="button"
          className="bare-button"
          aria-label="Host a watch party room"
          onClick={() => setCreateOpen(true)}
          style={{
            padding: '14px 16px',
            background: linear([AppColors.deepRose, AppColors.rosePressed]),
            borderRadius: AppRadius.md,
            boxShadow: boxShadow([{ offset: [0, 6], blur: 16, color: withAlpha(AppColors.deepRose, 0.35) }]),
            display: 'flex',
            alignItems: 'center',
            gap: 10,
          }}
        >
          <Icon name="add_circle_outline" size={22} color={AppColors.petalWhite} />
          <span style={{ flex: 1, textAlign: 'left', ...AppTypography.outfitBold, fontSize: 14, color: AppColors.petalWhite }}>
            Host a Watch Party
          </span>
          <span style={{ ...AppTypography.outfitWhite, fontSize: 11, color: withAlpha(AppColors.petalWhite, 0.78) }}>
            Optional password
          </span>
        </button>

        <div style={{ height: AppSpacing.md }} />

        {rooms.length === 0 ? (
          <div
            style={{
              padding: 28,
              borderRadius: AppRadius.md,
              background: Derived.surfaceGlass,
              border: `1px solid ${Derived.border}`,
              textAlign: 'center',
            }}
          >
            <Icon name="meeting_room" variant="outlined" size={32} color={AppColors.roseQuartz} />
            <div style={{ height: 8 }} />
            <div style={{ ...AppTypography.outfitHeading, fontSize: 15 }}>No watch parties yet</div>
            <div style={{ height: 4 }} />
            <div style={{ ...AppTypography.outfitMedium, fontSize: 12.5, color: Derived.textMuted }}>
              Host a room for Cinema movies, series, or Anime. Leave the password blank for an open room.
            </div>
          </div>
        ) : (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 10, paddingBottom: 12 }}>
            {rooms.map((room) => {
              const live = isRoomLive(room);
              const hosting = room.hostUid === myUid;
              const canDelete = hosting || auth.isCoupleUser;
              const accent = live ? AppColors.success : AppColors.mutedPurple;
              const subtitle =
                !room.tmdbId && !room.title
                  ? 'Picking a Cinema or Anime title…'
                  : room.mediaType === 'tv' || room.isAnime
                    ? `${room.title} · ${room.isAnime ? `Ep ${room.episode ?? 1}` : `S${room.season ?? 1} E${room.episode ?? 1}`}`
                    : room.title;
              const poster = resolvePoster(room.posterPath);

              return (
                <div
                  key={room.id}
                  style={{
                    padding: 10,
                    background: Derived.surfaceGlass,
                    borderRadius: AppRadius.md,
                    border: `1px solid ${live ? withAlpha(AppColors.deepRose, 0.55) : Derived.border}`,
                    display: 'flex',
                    alignItems: 'center',
                    gap: 10,
                  }}
                >
                  <button
                    type="button"
                    className="bare-button"
                    onClick={() => void handleJoinClick(room)}
                    style={{ flex: 1, minWidth: 0, display: 'flex', alignItems: 'center', gap: 12, textAlign: 'left' }}
                  >
                    <div
                      style={{
                        width: 52,
                        height: 72,
                        borderRadius: AppRadius.sm,
                        overflow: 'hidden',
                        background: AppColors.shimmerBase,
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'center',
                        flexShrink: 0,
                      }}
                    >
                      {poster ? (
                        <img
                          src={poster}
                          alt={room.title}
                          style={{ width: '100%', height: '100%', objectFit: 'cover', display: 'block' }}
                        />
                      ) : (
                        <Icon name="movie_filter" size={24} color={AppColors.mutedPurple} />
                      )}
                    </div>
                    <div style={{ flex: 1, minWidth: 0 }}>
                      <div style={{ display: 'flex', alignItems: 'center', gap: 6, flexWrap: 'wrap' }}>
                        <span
                          style={{
                            ...AppTypography.outfitHeading,
                            color: AppColors.petalWhite,
                            fontSize: 15,
                            whiteSpace: 'nowrap',
                            overflow: 'hidden',
                            textOverflow: 'ellipsis',
                          }}
                        >
                          {room.name}
                        </span>
                        <span
                          style={{
                            padding: '2px 6px',
                            borderRadius: 6,
                            background: withAlpha(accent, 0.16),
                            ...AppTypography.outfitWhite,
                            color: accent,
                            fontSize: 8.5,
                            fontWeight: 800,
                            letterSpacing: '1px',
                          }}
                        >
                          {live ? 'LIVE' : 'IDLE'}
                        </span>
                        <span
                          style={{
                            padding: '2px 6px',
                            borderRadius: 6,
                            background: room.hasPassword
                              ? withAlpha(AppColors.blushGold, 0.16)
                              : withAlpha(AppColors.petalWhite, 0.08),
                            color: room.hasPassword ? AppColors.blushGold : Derived.textMedium,
                            fontSize: 9.5,
                            fontWeight: 700,
                            display: 'inline-flex',
                            alignItems: 'center',
                            gap: 3,
                          }}
                        >
                          <Icon
                            name={room.hasPassword ? 'lock' : 'lock_open'}
                            size={11}
                            color={room.hasPassword ? AppColors.blushGold : Derived.textMedium}
                          />
                          <span>{room.hasPassword ? 'Password' : 'Open'}</span>
                        </span>
                      </div>
                      <div style={{ height: 4 }} />
                      <div
                        style={{
                          ...AppTypography.outfitWhite,
                          color: Derived.textMedium,
                          fontSize: 12,
                          whiteSpace: 'nowrap',
                          overflow: 'hidden',
                          textOverflow: 'ellipsis',
                        }}
                      >
                        {subtitle}
                      </div>
                      <div style={{ height: 5 }} />
                      <div style={{ ...AppTypography.outfitWhite, color: Derived.textMuted, fontSize: 11 }}>
                        {hosting ? 'Hosted by you' : `Hosted by ${displayNameFor(room.hostName)}`} · Everglow Server
                      </div>
                    </div>
                    <Icon
                      name={room.hasPassword && !hosting ? 'lock' : 'play_arrow'}
                      size={22}
                      color={live ? AppColors.roseQuartz : Derived.textMuted}
                    />
                  </button>
                  {canDelete && (
                    <button
                      type="button"
                      className="bare-button"
                      aria-label={`Delete ${room.name}`}
                      onClick={() => void deleteCommunityWatchPartyRoom(room.id)}
                      style={{
                        width: 32,
                        height: 32,
                        borderRadius: '50%',
                        background: withAlpha(AppColors.petalWhite, 0.06),
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'center',
                        flexShrink: 0,
                      }}
                    >
                      <Icon name="delete_outline" size={16} color={Derived.textMuted} />
                    </button>
                  )}
                </div>
              );
            })}
          </div>
        )}
      </div>

      {createOpen && (
        <div
          onClick={() => setCreateOpen(false)}
          style={{
            position: 'fixed',
            inset: 0,
            background: withAlpha(AppColors.inkDeep, 0.76),
            zIndex: 1100,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            padding: 20,
          }}
        >
          <div
            onClick={(e) => e.stopPropagation()}
            style={{
              width: '100%',
              maxWidth: 390,
              padding: 20,
              borderRadius: 20,
              background: AppColors.inkDeep,
              border: `1px solid ${Derived.border}`,
              display: 'flex',
              flexDirection: 'column',
              gap: 12,
            }}
          >
            <div style={{ ...AppTypography.cormorantBoldWhite, fontSize: 22 }}>Host Watch Party</div>
            <label style={{ display: 'flex', flexDirection: 'column', gap: 5 }}>
              <span style={{ ...AppTypography.outfitBold, fontSize: 12, color: Derived.textMedium }}>Room Name</span>
              <input
                autoFocus
                value={roomName}
                onChange={(e) => setRoomName(e.target.value)}
                placeholder="e.g. Friday Anime Night"
                maxLength={80}
                style={{
                  padding: '10px 14px',
                  borderRadius: 12,
                  background: AppColors.shimmerBase,
                  border: `1px solid ${Derived.border}`,
                  color: AppColors.petalWhite,
                  outline: 'none',
                  ...AppTypography.outfitMedium,
                }}
              />
            </label>
            <label style={{ display: 'flex', flexDirection: 'column', gap: 5 }}>
              <span style={{ ...AppTypography.outfitBold, fontSize: 12, color: Derived.textMedium }}>
                Room Password (optional)
              </span>
              <input
                type="password"
                value={roomPassword}
                onChange={(e) => setRoomPassword(e.target.value)}
                placeholder="Leave blank for anyone to join"
                maxLength={64}
                onKeyDown={(e) => {
                  if (e.key === 'Enter') void handleCreate();
                }}
                style={{
                  padding: '10px 14px',
                  borderRadius: 12,
                  background: AppColors.shimmerBase,
                  border: `1px solid ${Derived.border}`,
                  color: AppColors.petalWhite,
                  outline: 'none',
                  ...AppTypography.outfitMedium,
                }}
              />
            </label>
            <div style={{ fontSize: 11.5, color: Derived.textMuted }}>
              You can pick any Cinema movie/series or Anime inside the room. Sync is locked to Everglow Server.
            </div>
            <div style={{ display: 'flex', justifyContent: 'flex-end', gap: 10, marginTop: 4 }}>
              <button
                type="button"
                className="bare-button"
                onClick={() => setCreateOpen(false)}
                style={{ padding: '8px 14px', color: Derived.textMuted }}
              >
                Cancel
              </button>
              <button
                type="button"
                className="bare-button"
                disabled={creating}
                onClick={() => void handleCreate()}
                style={{
                  padding: '8px 18px',
                  borderRadius: 999,
                  background: AppColors.deepRose,
                  color: AppColors.petalWhite,
                  ...AppTypography.outfitBold,
                  opacity: creating ? 0.6 : 1,
                }}
              >
                {creating ? 'Creating…' : 'Host Room'}
              </button>
            </div>
          </div>
        </div>
      )}

      {joiningRoom && (
        <div
          onClick={() => setJoiningRoom(null)}
          style={{
            position: 'fixed',
            inset: 0,
            background: withAlpha(AppColors.inkDeep, 0.76),
            zIndex: 1100,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            padding: 20,
          }}
        >
          <div
            onClick={(e) => e.stopPropagation()}
            style={{
              width: '100%',
              maxWidth: 380,
              padding: 20,
              borderRadius: 20,
              background: AppColors.inkDeep,
              border: `1px solid ${Derived.border}`,
              display: 'flex',
              flexDirection: 'column',
              gap: 12,
            }}
          >
            <div style={{ ...AppTypography.cormorantBoldWhite, fontSize: 21 }}>Enter Room Password</div>
            <div style={{ fontSize: 12.5, color: Derived.textMuted }}>
              <strong>{joiningRoom.name}</strong> requires a password to join.
            </div>
            <input
              autoFocus
              type="password"
              value={joinPassword}
              onChange={(e) => {
                setJoinPassword(e.target.value);
                if (joinError) setJoinError(null);
              }}
              placeholder="Room password"
              onKeyDown={(e) => {
                if (e.key === 'Enter') void handleVerifyPassword();
              }}
              style={{
                padding: '10px 14px',
                borderRadius: 12,
                background: AppColors.shimmerBase,
                border: `1px solid ${joinError ? AppColors.error : Derived.border}`,
                color: AppColors.petalWhite,
                outline: 'none',
                ...AppTypography.outfitMedium,
              }}
            />
            {joinError && (
              <div role="alert" style={{ fontSize: 12, color: AppColors.error }}>
                {joinError}
              </div>
            )}
            <div style={{ display: 'flex', justifyContent: 'flex-end', gap: 10 }}>
              <button
                type="button"
                className="bare-button"
                onClick={() => setJoiningRoom(null)}
                style={{ padding: '8px 14px', color: Derived.textMuted }}
              >
                Cancel
              </button>
              <button
                type="button"
                className="bare-button"
                onClick={() => void handleVerifyPassword()}
                style={{
                  padding: '8px 18px',
                  borderRadius: 999,
                  background: AppColors.deepRose,
                  color: AppColors.petalWhite,
                  ...AppTypography.outfitBold,
                }}
              >
                Join Room
              </button>
            </div>
          </div>
        </div>
      )}
    </>
  );
}

/** `openWatchPartyRoom`: push the room screen over the current page. */
export function useOpenWatchPartyRoom() {
  const navigate = useNavigate();
  return (roomId: string) => navigate(`/watch-party?room=${encodeURIComponent(roomId)}`);
}

/** `WatchPartyLobby`: the create button and room list; `embedded` drops the big header. */
export function WatchPartyLobby({ embedded = false }: { embedded?: boolean }) {
  const auth = useAuth();
  const openRoom = useOpenWatchPartyRoom();
  const myUid = auth.uid ?? '';
  const rooms = useSource(() => roomsStream(myUid), [myUid], []);
  const [createOpen, setCreateOpen] = useState(false);
  const [newRoomName, setNewRoomName] = useState('');

  const handleCreate = async () => {
    if (!myUid || !auth.partnerUid) return;
    try {
      const room = await createWatchPartyRoom({
        hostUid: myUid,
        hostName: auth.currentUser ?? 'Khent',
        partnerUid: auth.partnerUid,
        partnerName: auth.partnerName,
        name: newRoomName,
      });
      setCreateOpen(false);
      setNewRoomName('');
      openRoom(room.id);
    } catch {
      showSnackBar('Could not create the room. Try again.');
    }
  };

  const handleOpenRoom = async (room: WatchPartyRoom) => {
    if (!isRoomLive(room)) {
      await updateWatchPartyRoom(room.id, { active: true, state: 'paused', updatedBy: myUid });
    }
    openRoom(room.id);
  };

  return (
    <>
      {!auth.isCoupleUser ? (
        <div
          style={{
            padding: 24,
            borderRadius: AppRadius.md,
            background: Derived.surfaceGlass,
            border: `1px solid ${Derived.border}`,
            textAlign: 'center',
          }}
        >
          <div style={{ ...AppTypography.outfitHeading, fontSize: 16 }}>Watch Together is for Khent &amp; Clair</div>
        </div>
      ) : (
        <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'stretch' }}>
          {!embedded && (
            <div style={{ marginBottom: AppSpacing.lg }}>
              <div style={{ ...AppTypography.outfitWhite, color: Derived.textMedium, fontSize: 13, lineHeight: 1.4 }}>
                Pick a room, or make a new one. Both of you can walk in.
              </div>
            </div>
          )}

          <button
            type="button"
            className="bare-button"
            aria-label="Create a watch party room"
            onClick={() => setCreateOpen(true)}
            style={{
              padding: '14px 16px',
              background: linear([AppColors.deepRose, AppColors.rosePressed]),
              borderRadius: AppRadius.md,
              boxShadow: boxShadow([{ offset: [0, 6], blur: 16, color: withAlpha(AppColors.deepRose, 0.35) }]),
              display: 'flex',
              alignItems: 'center',
              gap: 10,
            }}
          >
            <Icon name="add" size={22} color={AppColors.petalWhite} />
            <span style={{ flex: 1, textAlign: 'left', ...AppTypography.outfitBold, fontSize: 14, color: AppColors.petalWhite }}>
              Create a room
            </span>
            <span style={{ ...AppTypography.outfitWhite, fontSize: 12.5, color: AppColors.petalWhite, opacity: 0.92 }}>
              No password
            </span>
          </button>

          <div style={{ height: AppSpacing.md }} />

          {rooms.length === 0 ? (
            <div
              style={{
                padding: 28,
                borderRadius: AppRadius.md,
                background: Derived.surfaceGlass,
                border: `1px solid ${Derived.border}`,
                textAlign: 'center',
              }}
            >
              <Icon name="meeting_room" variant="outlined" size={32} color={AppColors.roseQuartz} />
              <div style={{ height: 8 }} />
              <div style={{ ...AppTypography.outfitHeading, fontSize: 15 }}>No rooms yet</div>
              <div style={{ height: 4 }} />
              <div style={{ ...AppTypography.outfitMedium, fontSize: 12.5, color: Derived.textMuted }}>
                Create one room for movie nights, one for anime, or one for each mood. No codes, no passwords.
              </div>
            </div>
          ) : (
            <div style={{ display: 'flex', flexDirection: 'column', gap: 10, paddingBottom: 10 }}>
              {rooms.map((room) => {
                const live = isRoomLive(room);
                const hosting = room.hostUid === myUid;
                const accent = live ? AppColors.success : AppColors.mutedPurple;
                const subtitle =
                  !room.tmdbId && !room.title
                    ? 'Nothing chosen yet'
                    : room.mediaType === 'tv'
                      ? `${room.title} · S${room.season ?? 1} E${room.episode ?? 1}`
                      : room.title;
                const poster = resolvePoster(room.posterPath);

                return (
                  <div
                    key={room.id}
                    style={{
                      padding: 10,
                      background: Derived.surfaceGlass,
                      borderRadius: AppRadius.md,
                      border: `1px solid ${live ? withAlpha(AppColors.deepRose, 0.55) : Derived.border}`,
                      display: 'flex',
                      alignItems: 'center',
                      gap: 10,
                    }}
                  >
                    <button
                      type="button"
                      className="bare-button"
                      onClick={() => void handleOpenRoom(room)}
                      style={{ flex: 1, minWidth: 0, display: 'flex', alignItems: 'center', gap: 12, textAlign: 'left' }}
                    >
                      <div
                        style={{
                          width: 52,
                          height: 72,
                          borderRadius: AppRadius.sm,
                          overflow: 'hidden',
                          background: AppColors.shimmerBase,
                          display: 'flex',
                          alignItems: 'center',
                          justifyContent: 'center',
                          flexShrink: 0,
                        }}
                      >
                        {poster ? (
                          <img
                            src={poster}
                            alt={room.title}
                            style={{ width: '100%', height: '100%', objectFit: 'cover', display: 'block' }}
                          />
                        ) : (
                          <Icon name="movie_filter" size={24} color={AppColors.mutedPurple} />
                        )}
                      </div>
                      <div style={{ flex: 1, minWidth: 0 }}>
                        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                          <span
                            style={{
                              ...AppTypography.outfitHeading,
                              color: AppColors.petalWhite,
                              fontSize: 15,
                              whiteSpace: 'nowrap',
                              overflow: 'hidden',
                              textOverflow: 'ellipsis',
                            }}
                          >
                            {room.name || 'Our room'}
                          </span>
                          <span
                            style={{
                              padding: '2px 6px',
                              borderRadius: 6,
                              background: withAlpha(accent, 0.16),
                              ...AppTypography.outfitWhite,
                              color: accent,
                              fontSize: 8.5,
                              fontWeight: 800,
                              letterSpacing: '1px',
                              flexShrink: 0,
                            }}
                          >
                            {live ? 'LIVE' : 'IDLE'}
                          </span>
                        </div>
                        <div style={{ height: 4 }} />
                        <div
                          style={{
                            ...AppTypography.outfitWhite,
                            color: Derived.textMedium,
                            fontSize: 12,
                            whiteSpace: 'nowrap',
                            overflow: 'hidden',
                            textOverflow: 'ellipsis',
                          }}
                        >
                          {subtitle}
                        </div>
                        <div style={{ height: 6 }} />
                        <div style={{ ...AppTypography.outfitWhite, color: Derived.textMuted, fontSize: 11 }}>
                          {hosting ? 'You are hosting' : `${room.hostName} is hosting`}
                        </div>
                      </div>
                      <Icon
                        name={live ? 'play_arrow' : 'chevron_right'}
                        size={22}
                        color={live ? AppColors.roseQuartz : Derived.textMuted}
                      />
                    </button>
                    <button
                      type="button"
                      className="bare-button"
                      aria-label={`Delete ${room.name || 'Our room'}`}
                      onClick={() => {
                        // The app's own dialog, not a browser prompt: this is a
                        // surface Clair uses, and 32px was below the touch floor.
                        void showDialog<void>((close) => (
                          <AlertDialog
                            title={<div style={{ ...AppTypography.outfitHeading, fontSize: 17 }}>{`Delete ${room.name || 'Our room'}?`}</div>}
                            content={
                              <div style={{ ...AppTypography.outfitWhite, fontSize: 14, color: Derived.textMuted }}>
                                Everyone in the room leaves, and the chat log with it.
                              </div>
                            }
                            actions={[
                              <TextButton key="cancel" onPressed={() => close(null)}>
                                Keep room
                              </TextButton>,
                              <TextButton
                                key="delete"
                                color={AppColors.roseQuartz}
                                onPressed={() => {
                                  close(null);
                                  void deleteWatchPartyRoom(room.id);
                                }}
                              >
                                Delete
                              </TextButton>,
                            ]}
                          />
                        ));
                      }}
                      style={{
                        width: 44,
                        height: 44,
                        borderRadius: '50%',
                        background: withAlpha(AppColors.petalWhite, 0.06),
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'center',
                        flexShrink: 0,
                      }}
                    >
                      <Icon name="delete_outline" size={16} color={Derived.textMuted} />
                    </button>
                  </div>
                );
              })}
            </div>
          )}
        </div>
      )}

      {createOpen && (
        <div
          onClick={() => setCreateOpen(false)}
          style={{
            position: 'fixed',
            inset: 0,
            background: withAlpha(AppColors.inkDeep, 0.72),
            zIndex: 1100,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            padding: 20,
          }}
        >
          <div
            onClick={(e) => e.stopPropagation()}
            style={{
              width: '100%',
              maxWidth: 380,
              padding: 20,
              borderRadius: 20,
              background: AppColors.inkDeep,
              border: `1px solid ${Derived.border}`,
              display: 'flex',
              flexDirection: 'column',
              gap: 12,
            }}
          >
            <div style={{ ...AppTypography.cormorantBoldWhite, fontSize: 22 }}>New Watch Party Room</div>
            <input
              autoFocus
              value={newRoomName}
              onChange={(e) => setNewRoomName(e.target.value)}
              placeholder="e.g. Movie Night"
              onKeyDown={(e) => {
                if (e.key === 'Enter') void handleCreate();
              }}
              style={{
                padding: '10px 14px',
                borderRadius: 12,
                background: AppColors.shimmerBase,
                border: `1px solid ${Derived.border}`,
                color: AppColors.petalWhite,
                outline: 'none',
                ...AppTypography.outfitMedium,
              }}
            />
            <div style={{ display: 'flex', justifyContent: 'flex-end', gap: 10 }}>
              <button
                type="button"
                className="bare-button"
                onClick={() => setCreateOpen(false)}
                style={{ padding: '8px 14px', color: Derived.textMuted }}
              >
                Cancel
              </button>
              <button
                type="button"
                className="bare-button"
                onClick={() => void handleCreate()}
                style={{
                  padding: '8px 18px',
                  borderRadius: 999,
                  background: AppColors.deepRose,
                  color: AppColors.petalWhite,
                  ...AppTypography.outfitBold,
                }}
              >
                Create
              </button>
            </div>
          </div>
        </div>
      )}
    </>
  );
}

function WatchPartyRoomView({
  roomId,
  scope,
  myUid,
  myName,
  isCoupleUser,
  onExit,
}: {
  roomId: string;
  scope: 'hub' | 'private';
  myUid: string;
  myName: string;
  isCoupleUser: boolean;
  onExit: () => void;
}) {
  const isHub = scope === 'hub';
  const { width } = useViewport();
  const room = useSource<WatchPartyRoom | CommunityWatchPartyRoom | null>(
    () => (isHub ? communityRoomStream(roomId) : roomStream(roomId)),
    [roomId, isHub],
    null,
  );
  const [unlocked, setUnlocked] = useState(() => !isHub || isCoupleUser || isCommunityRoomUnlocked(roomId));
  const [gatePassword, setGatePassword] = useState('');
  const [gateError, setGateError] = useState<string | null>(null);
  const [gateBusy, setGateBusy] = useState(false);

  const communityRoomForGate = isHub ? (room as CommunityWatchPartyRoom | null) : null;
  const canReadChat =
    !isHub ||
    Boolean(
      communityRoomForGate &&
        (!communityRoomForGate.hasPassword ||
          communityRoomForGate.hostUid === myUid ||
          isCoupleUser ||
          unlocked),
    );

  useEffect(() => {
    if (!isHub || !communityRoomForGate?.hasPassword || unlocked || communityRoomForGate.hostUid === myUid || isCoupleUser) {
      return;
    }
    let cancelled = false;
    void checkCommunityRoomMembership(roomId, myUid).then((isMember) => {
      if (!cancelled && isMember) setUnlocked(true);
    });
    return () => {
      cancelled = true;
    };
  }, [isHub, roomId, myUid, isCoupleUser, unlocked, communityRoomForGate?.hasPassword, communityRoomForGate?.hostUid]);

  const messages = useSource<WatchPartyChatMessage[]>(
    () => (canReadChat ? (isHub ? communityRoomChatStream(roomId) : roomChatStream(roomId)) : null),
    [roomId, isHub, canReadChat],
    [],
  );
  const clock = useMemo(() => new WatchPartyClock(), []);
  const iframeRef = useRef<HTMLIFrameElement | null>(null);
  const suppressEmbedEventsUntil = useRef(0);
  const roomRef = useRef(room);
  roomRef.current = room;
  const [chatOpen, setChatOpen] = useState(false);
  const [msgText, setMsgText] = useState('');

  const postEmbedCommand = (command: string, args: unknown[] = []) => {
    const frame = iframeRef.current;
    const win = frame?.contentWindow;
    if (!frame || !win) return;
    let targetOrigin = window.location.origin;
    try {
      if (frame.src) targetOrigin = new URL(frame.src, window.location.origin).origin;
    } catch {
      return;
    }
    suppressEmbedEventsUntil.current = Date.now() + 900;
    try {
      win.postMessage(cinesrcCommand(command, args), targetOrigin);
    } catch {
      // Cross-origin frame not ready yet.
    }
  };

  const patchRoom = (patch: Record<string, unknown>) =>
    isHub ? updateCommunityWatchPartyRoom(roomId, patch) : updateWatchPartyRoom(roomId, patch);

  const swapMedia = (picked: Parameters<typeof updateRoomMedia>[1]) =>
    isHub ? updateCommunityRoomMedia(roomId, picked, myUid) : updateRoomMedia(roomId, picked, myUid);

  const sendChat = (text: string) =>
    isHub
      ? sendCommunityRoomChatMessage(roomId, myUid, myName, text)
      : sendRoomChatMessage(roomId, myUid, myName, text);

  useEffect(() => {
    if (!room) return;
    clock.observe(room.positionAt ?? room.updatedAt);
  }, [room, clock]);

  // Tab-close cleanup: pause room if host leaves the browser tab.
  useEffect(() => {
    if (!room || room.hostUid !== myUid) return;
    const onUnload = () => {
      void patchRoom({ state: 'paused', updatedBy: myUid }).catch(() => {});
    };
    window.addEventListener('pagehide', onUnload);
    window.addEventListener('beforeunload', onUnload);
    return () => {
      window.removeEventListener('pagehide', onUnload);
      window.removeEventListener('beforeunload', onUnload);
    };
  }, [room?.id, room?.hostUid, myUid, isHub]);

  // CineSrc postMessage bridge for embed playback sync.
  const isEmbedMode = Boolean(room && room.serverType !== 'hls');
  useEffect(() => {
    if (!isEmbedMode) return;
    const onMessage = (e: MessageEvent) => {
      const frame = iframeRef.current;
      if (!frame || e.source !== frame.contentWindow) return;
      let expectedOrigin = window.location.origin;
      try {
        if (frame.src) expectedOrigin = new URL(frame.src, window.location.origin).origin;
      } catch {
        return;
      }
      if (e.origin !== expectedOrigin) return;
      const currentRoom = roomRef.current;
      if (!currentRoom || currentRoom.serverType === 'hls') return;
      const ev = parseCinesrcEvent(e.data);
      if (!ev || Date.now() < suppressEmbedEventsUntil.current) return;
      if (ev.name === 'play' && currentRoom.state !== 'playing') {
        void patchRoom({
          state: 'playing',
          currentTime: ev.currentTime ?? clock.expectedPosition(currentRoom),
          updatedBy: myUid,
        });
      } else if (ev.name === 'pause' && currentRoom.state === 'playing') {
        void patchRoom({
          state: 'paused',
          currentTime: ev.currentTime ?? clock.expectedPosition(currentRoom),
          updatedBy: myUid,
        });
      } else if ((ev.name === 'seeked' || ev.name === 'timeupdate') && ev.currentTime != null) {
        if (isUserSeek(clock.expectedPosition(currentRoom), ev.currentTime, 2.5)) {
          void patchRoom({
            currentTime: ev.currentTime,
            updatedBy: myUid,
          });
        }
      }
    };
    window.addEventListener('message', onMessage);
    return () => window.removeEventListener('message', onMessage);
  }, [isEmbedMode, myUid, clock, isHub, roomId]);

  // Push remote play/pause/seek state into the CineSrc embed iframe.
  useEffect(() => {
    if (!room || room.serverType === 'hls') return;
    if (room.updatedBy === myUid) return;
    const frame = iframeRef.current;
    const win = frame?.contentWindow;
    if (!frame || !win) return;
    let targetOrigin = window.location.origin;
    try {
      if (frame.src) targetOrigin = new URL(frame.src, window.location.origin).origin;
    } catch {
      return;
    }
    const expected = clock.expectedPosition(room);
    try {
      win.postMessage(cinesrcCommand('seek', [expected]), targetOrigin);
      win.postMessage(cinesrcCommand(room.state === 'playing' ? 'play' : 'pause'), targetOrigin);
    } catch {
      // Cross-origin frame not ready yet.
    }
  }, [room?.state, room?.currentTime, room?.serverType, room?.updatedBy, myUid, clock]);

  if (!room) {
    return (
      <div
        style={{
          position: 'fixed',
          inset: 0,
          background: '#000000',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
        }}
      >
        <span style={{ ...AppTypography.outfitMedium, color: AppColors.petalWhite }}>Connecting to room…</span>
      </div>
    );
  }

  const communityRoom = isHub ? (room as CommunityWatchPartyRoom) : null;
  const needsPasswordGate = Boolean(
    communityRoom && communityRoom.hasPassword && communityRoom.hostUid !== myUid && !isCoupleUser && !unlocked,
  );

  if (needsPasswordGate && communityRoom) {
    const submitGate = async () => {
      if (gateBusy) return;
      setGateBusy(true);
      setGateError(null);
      try {
        const res = await unlockCommunityWatchPartyRoom(communityRoom.id, gatePassword);
        if (!res.ok) {
          setGateError(res.error || 'Incorrect room password.');
          return;
        }
        setUnlocked(true);
        setGateError(null);
      } finally {
        setGateBusy(false);
      }
    };
    return (
      <div
        style={{
          position: 'fixed',
          inset: 0,
          background: AppColors.inkDeep,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          padding: 20,
        }}
      >
        <div
          style={{
            width: '100%',
            maxWidth: 380,
            padding: 22,
            borderRadius: 20,
            background: Derived.surfaceGlass,
            border: `1px solid ${Derived.border}`,
            display: 'flex',
            flexDirection: 'column',
            gap: 12,
          }}
        >
          <div style={{ ...AppTypography.cormorantBoldWhite, fontSize: 22 }}>{communityRoom.name}</div>
          <div style={{ fontSize: 12.5, color: Derived.textMuted }}>
            Hosted by <strong>{displayNameFor(communityRoom.hostName)}</strong>. Enter the room password to join.
          </div>
          <input
            autoFocus
            type="password"
            value={gatePassword}
            onChange={(e) => {
              setGatePassword(e.target.value);
              if (gateError) setGateError(null);
            }}
            placeholder="Room password"
            onKeyDown={(e) => {
              if (e.key === 'Enter') void submitGate();
            }}
            style={{
              padding: '10px 14px',
              borderRadius: 12,
              background: AppColors.shimmerBase,
              border: `1px solid ${gateError ? AppColors.error : Derived.border}`,
              color: AppColors.petalWhite,
              outline: 'none',
              ...AppTypography.outfitMedium,
            }}
          />
          {gateError && (
            <div role="alert" style={{ fontSize: 12, color: AppColors.error }}>
              {gateError}
            </div>
          )}
          <div style={{ display: 'flex', justifyContent: 'flex-end', gap: 10 }}>
            <button type="button" className="bare-button" onClick={onExit} style={{ padding: '8px 14px', color: Derived.textMuted }}>
              Back
            </button>
            <button
              type="button"
              className="bare-button"
              onClick={() => void submitGate()}
              style={{
                padding: '8px 18px',
                borderRadius: 999,
                background: AppColors.deepRose,
                color: AppColors.petalWhite,
                ...AppTypography.outfitBold,
              }}
            >
              Enter Room
            </button>
          </div>
        </div>
      </div>
    );
  }

  const compact = width < 700;
  const hasMedia = room.tmdbId > 0 || room.title.length > 0;
  const isHlsMode = room.serverType === 'hls';
  const everglowEmbed = BUILTIN_WATCH_PARTY_SERVERS.find((s) => s.type === 'embed');
  const embedSrc = hasMedia
    ? room.isAnime
      ? `https://everglow-stream.khentplaysmoba.workers.dev/proxyAnime?source=everglow&malId=${room.malId ?? room.tmdbId}&ep=${room.episode ?? 1}&audio=sub`
      : `https://everglow-1c6db.web.app/embed.html?source=cinema&type=${room.mediaType}&tmdbId=${room.tmdbId}${room.mediaType === 'tv' ? `&s=${room.season ?? 1}&e=${room.episode ?? 1}` : ''}&title=${encodeURIComponent(room.title)}`
    : '';

  const togglePlay = () => {
    const nextState = room.state === 'playing' ? 'paused' : 'playing';
    const nextTime = clock.expectedPosition(room);
    if (!isHlsMode) {
      postEmbedCommand(nextState === 'playing' ? 'play' : 'pause');
    }
    void patchRoom({
      state: nextState,
      currentTime: nextTime,
      updatedBy: myUid,
    });
  };

  const openMediaPicker = async () => {
    const picked = await showWatchPartyMediaPicker({
      currentTitle: room.title,
      initialCategory: room.isAnime ? 'anime' : 'cinema',
    });
    if (!picked) return;
    await swapMedia(picked);
    showSnackBar(`Switched to ${picked.title}`);
  };

  const openEpisodePicker = async () => {
    if (!hasMedia || (room.mediaType !== 'tv' && !room.isAnime)) return;
    const picked = await showEpisodePicker({
      title: room.title,
      isAnime: room.isAnime,
      maxEpisodes: room.episodeCount,
    });
    if (!picked) return;
    await patchRoom({
      season: picked.season,
      episode: picked.episode,
      currentTime: 0,
      state: 'paused',
      updatedBy: myUid,
    });
    showSnackBar(room.isAnime ? `Episode ${picked.episode}` : `S${picked.season} E${picked.episode}`);
  };

  return (
    <div style={{ position: 'fixed', inset: 0, background: '#000000', display: 'flex', flexDirection: 'column' }}>
      <header
        style={{
          height: 56,
          padding: `8px ${compact ? 10 : 16}px`,
          background: AppColors.inkDeep,
          borderBottom: `1px solid ${withAlpha(AppColors.moonlight, 0.14)}`,
          display: 'flex',
          alignItems: 'center',
          gap: 8,
          flexShrink: 0,
        }}
      >
        <button type="button" className="bare-button" aria-label="Leave room" onClick={onExit} style={{ padding: 6 }}>
          <Icon name="arrow_back" size={22} color={AppColors.petalWhite} />
        </button>
        <div style={{ flex: 1, minWidth: 0 }}>
          <div
            style={{
              ...AppTypography.outfitHeading,
              fontSize: 15,
              color: AppColors.petalWhite,
              whiteSpace: 'nowrap',
              overflow: 'hidden',
              textOverflow: 'ellipsis',
            }}
          >
            {room.name || 'Watch Together'}
          </div>
          <div
            style={{
              ...AppTypography.outfitWhite,
              fontSize: 11,
              color: AppColors.roseQuartz,
              whiteSpace: 'nowrap',
              overflow: 'hidden',
              textOverflow: 'ellipsis',
            }}
          >
            {hasMedia
              ? room.mediaType === 'tv' || room.isAnime
                ? `${room.title} · ${room.isAnime ? `Ep ${room.episode ?? 1}` : `S${room.season ?? 1} E${room.episode ?? 1}`}`
                : room.title
              : 'Pick a title'}
          </div>
        </div>
        {hasMedia && (room.mediaType === 'tv' || room.isAnime) && (
          <button
            type="button"
            className="bare-button"
            aria-label="Pick episode"
            onClick={() => void openEpisodePicker()}
            style={{
              padding: '7px 10px',
              borderRadius: 999,
              background: withAlpha(AppColors.petalWhite, 0.07),
              border: `1px solid ${withAlpha(AppColors.petalWhite, 0.16)}`,
              display: 'inline-flex',
              alignItems: 'center',
              gap: 5,
              color: AppColors.petalWhite,
              ...AppTypography.outfitHeading,
              fontSize: 11.5,
            }}
          >
            <Icon name="format_list_numbered" size={15} color={AppColors.blushGold} />
            {!compact && <span>Episodes</span>}
          </button>
        )}
        <div
          title="Watch Party playback is locked to Everglow Server for reliable sync"
          style={{
            padding: '7px 10px',
            borderRadius: 999,
            background: withAlpha(AppColors.blushGold, 0.12),
            border: `1px solid ${withAlpha(AppColors.blushGold, 0.35)}`,
            display: 'inline-flex',
            alignItems: 'center',
            gap: 5,
            color: AppColors.blushGold,
            ...AppTypography.outfitHeading,
            fontSize: 11.5,
          }}
        >
          <Icon name="lock" size={14} color={AppColors.blushGold} />
          {!compact && <span>Everglow Server</span>}
        </div>
        <button
          type="button"
          className="bare-button"
          onClick={() => void openMediaPicker()}
          style={{
            padding: '7px 12px',
            borderRadius: 999,
            background: withAlpha(AppColors.deepRose, 0.16),
            border: `1px solid ${withAlpha(AppColors.deepRose, 0.55)}`,
            display: 'inline-flex',
            alignItems: 'center',
            gap: 6,
            color: AppColors.deepRose,
            ...AppTypography.outfitHeading,
            fontSize: 11.5,
          }}
        >
          <Icon name="search" size={15} color={AppColors.deepRose} />
          {!compact && <span>Pick Title</span>}
        </button>
        <button
          type="button"
          className="bare-button"
          onClick={() => setChatOpen((v) => !v)}
          style={{
            padding: '7px 12px',
            borderRadius: 999,
            background: withAlpha(AppColors.petalWhite, 0.06),
            border: `1px solid ${withAlpha(AppColors.petalWhite, 0.16)}`,
            display: 'inline-flex',
            alignItems: 'center',
            gap: 6,
            color: AppColors.petalWhite,
            ...AppTypography.outfitHeading,
            fontSize: 11.5,
          }}
        >
          <Icon name="chat_bubble_outline" size={15} color={AppColors.petalWhite} />
          {!compact && <span>{`Chat (${messages.length})`}</span>}
        </button>
      </header>

      <div style={{ flex: 1, display: 'flex', overflow: 'hidden', position: 'relative' }}>
        <div style={{ flex: 1, overflowY: 'auto', padding: '16px 0' }}>
          {!hasMedia ? (
            <div style={{ maxWidth: 760, margin: '0 auto', padding: `0 ${AppSpacing.xl}px` }}>
              <div
                style={{
                  aspectRatio: '16 / 9',
                  borderRadius: AppRadius.md,
                  background: linear([AppColors.plum, AppColors.inkDeep], { begin: Align.topLeft, end: Align.bottomRight }),
                  border: `1px solid ${Derived.border}`,
                  display: 'flex',
                  flexDirection: 'column',
                  alignItems: 'center',
                  justifyContent: 'center',
                  padding: 20,
                  textAlign: 'center',
                }}
              >
                <Icon name="movie_filter" size={36} color={AppColors.roseQuartz} />
                <div style={{ height: 10 }} />
                <div style={{ ...AppTypography.cormorantBoldWhite, fontSize: 20 }}>Nothing playing yet</div>
                <div style={{ height: 4 }} />
                <div style={{ ...AppTypography.outfitWhite, color: Derived.textMuted, fontSize: 12 }}>
                  Pick a Cinema movie, series, or Anime to watch together on Everglow Server.
                </div>
                <div style={{ height: 16 }} />
                <button
                  type="button"
                  className="bare-button"
                  onClick={() => void openMediaPicker()}
                  style={{
                    padding: '12px 20px',
                    borderRadius: 999,
                    background: linear([AppColors.deepRose, AppColors.rosePressed]),
                    display: 'inline-flex',
                    alignItems: 'center',
                    gap: 8,
                    ...AppTypography.outfitBold,
                    color: AppColors.petalWhite,
                    fontSize: 13,
                  }}
                >
                  <Icon name="search" size={18} color={AppColors.petalWhite} />
                  <span>Choose a title</span>
                </button>
              </div>
            </div>
          ) : (
            <div style={{ maxWidth: 960, margin: '0 auto', padding: '0 16px' }}>
              <div
                style={{
                  aspectRatio: '16 / 9',
                  background: '#000000',
                  borderRadius: 12,
                  overflow: 'hidden',
                  border: `1px solid ${Derived.border}`,
                }}
              >
                {isHlsMode ? (
                  <HlsServerPlayer
                    room={room}
                    clock={clock}
                    onUserPlay={(sec) => void patchRoom({ state: 'playing', currentTime: sec, updatedBy: myUid })}
                    onUserPause={(sec) => void patchRoom({ state: 'paused', currentTime: sec, updatedBy: myUid })}
                    onUserSeek={(sec) => void patchRoom({ currentTime: sec, updatedBy: myUid })}
                    onFallbackToEmbed={() =>
                      void patchRoom({
                        serverType: everglowEmbed?.type ?? 'embed',
                        serverName: 'Everglow Server',
                        serverHost: 'everglow',
                        updatedBy: myUid,
                      })
                    }
                  />
                ) : (
                  <iframe
                    ref={iframeRef}
                    key={embedSrc}
                    src={embedSrc}
                    title={room.title}
                    allowFullScreen
                    allow="autoplay; fullscreen; picture-in-picture; encrypted-media"
                    sandbox="allow-scripts allow-same-origin allow-forms allow-presentation"
                    style={{ width: '100%', height: '100%', border: 'none', display: 'block' }}
                  />
                )}
              </div>
              <div
                style={{
                  marginTop: 12,
                  padding: '10px 14px',
                  borderRadius: 12,
                  background: AppColors.inkDeep,
                  border: `1px solid ${Derived.border}`,
                  display: 'flex',
                  alignItems: 'center',
                  gap: 10,
                  flexWrap: 'wrap',
                }}
              >
                <button
                  type="button"
                  className="bare-button"
                  onClick={togglePlay}
                  style={{
                    width: 38,
                    height: 38,
                    borderRadius: '50%',
                    background: AppColors.deepRose,
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                  }}
                >
                  <Icon name={room.state === 'playing' ? 'pause' : 'play_arrow'} size={22} color="#FFFFFF" />
                </button>
                <div style={{ flex: 1, minWidth: 160 }}>
                  <div style={{ ...AppTypography.outfitBold, fontSize: 13, color: AppColors.petalWhite }}>
                    {room.state === 'playing' ? 'Synced Playback: Playing' : 'Synced Playback: Paused'}
                  </div>
                  <PartyPositionLine room={room} clock={clock} myUid={myUid} isHub={isHub} />
                </div>
                <button
                  type="button"
                  className="bare-button"
                  onClick={() => {
                    const target = Math.max(0, clock.expectedPosition(room) - 15);
                    if (!isHlsMode) postEmbedCommand('seek', [target]);
                    void patchRoom({
                      currentTime: target,
                      updatedBy: myUid,
                    });
                  }}
                  style={{
                    padding: '6px 10px',
                    borderRadius: 8,
                    background: AppColors.shimmerBase,
                    color: AppColors.petalWhite,
                    fontSize: 11.5,
                  }}
                >
                  -15s
                </button>
                <button
                  type="button"
                  className="bare-button"
                  onClick={() => {
                    const target = Math.max(0, clock.expectedPosition(room) + 15);
                    if (!isHlsMode) postEmbedCommand('seek', [target]);
                    void patchRoom({
                      currentTime: target,
                      updatedBy: myUid,
                    });
                  }}
                  style={{
                    padding: '6px 10px',
                    borderRadius: 8,
                    background: AppColors.shimmerBase,
                    color: AppColors.petalWhite,
                    fontSize: 11.5,
                  }}
                >
                  +15s
                </button>
              </div>
            </div>
          )}
        </div>

        {chatOpen && (
          <aside
            style={{
              width: compact ? '100%' : 320,
              position: compact ? 'absolute' : 'relative',
              inset: compact ? 0 : undefined,
              background: AppColors.inkDeep,
              borderLeft: `1px solid ${Derived.border}`,
              display: 'flex',
              flexDirection: 'column',
              zIndex: 40,
            }}
          >
            <div
              style={{
                padding: '12px 14px',
                borderBottom: `1px solid ${Derived.border}`,
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'space-between',
              }}
            >
              <span style={{ ...AppTypography.outfitHeading, fontSize: 14 }}>Room Chat</span>
              <button type="button" className="bare-button" onClick={() => setChatOpen(false)}>
                <Icon name="close" size={18} color={AppColors.petalWhite} />
              </button>
            </div>
            <div
              className="no-scrollbar"
              style={{ flex: 1, overflowY: 'auto', padding: 12, display: 'flex', flexDirection: 'column', gap: 8 }}
            >
              {messages.map((m) => (
                <div key={m.id} style={{ alignSelf: m.senderUid === myUid ? 'flex-end' : 'flex-start', maxWidth: '82%' }}>
                  <div style={{ fontSize: 10, color: Derived.textMuted, marginBottom: 2 }}>{displayNameFor(m.senderName)}</div>
                  <div
                    style={{
                      padding: '8px 12px',
                      borderRadius: 12,
                      background: m.senderUid === myUid ? AppColors.deepRose : AppColors.shimmerBase,
                      fontSize: 12.5,
                      color: AppColors.petalWhite,
                    }}
                  >
                    {m.text}
                  </div>
                </div>
              ))}
            </div>
            <div style={{ padding: 10, borderTop: `1px solid ${Derived.border}`, display: 'flex', gap: 8 }}>
              <input
                value={msgText}
                onChange={(e) => setMsgText(e.target.value)}
                placeholder="Say something…"
                onKeyDown={(e) => {
                  if (e.key === 'Enter' && msgText.trim()) {
                    void sendChat(msgText);
                    setMsgText('');
                  }
                }}
                style={{
                  flex: 1,
                  padding: '8px 12px',
                  borderRadius: 999,
                  background: AppColors.shimmerBase,
                  border: `1px solid ${Derived.border}`,
                  color: AppColors.petalWhite,
                  outline: 'none',
                  fontSize: 12.5,
                }}
              />
              <button
                type="button"
                className="bare-button"
                onClick={() => {
                  if (msgText.trim()) {
                    void sendChat(msgText);
                    setMsgText('');
                  }
                }}
                style={{
                  width: 36,
                  height: 36,
                  borderRadius: '50%',
                  background: AppColors.deepRose,
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                }}
              >
                <Icon name="send" size={16} color="#FFFFFF" />
              </button>
            </div>
          </aside>
        )}
      </div>
    </div>
  );
}

/**
 * The position line is the only thing on this screen that changes every
 * second. Keeping the tick in its own leaf stops the whole party page (and the
 * embed around it) from re-rendering once a second during playback.
 */
function PartyPositionLine({
  room,
  clock,
  myUid,
  isHub,
}: {
  room: WatchPartyRoom;
  clock: WatchPartyClock;
  myUid: string;
  isHub: boolean;
}) {
  const [seconds, setSeconds] = useState(() => clock.expectedPosition(room));
  useEffect(() => {
    setSeconds(clock.expectedPosition(room));
    if (room.state !== 'playing') return;
    const id = window.setInterval(() => {
      if (document.visibilityState === 'visible') setSeconds(clock.expectedPosition(room));
    }, 1000);
    return () => window.clearInterval(id);
  }, [room, clock]);
  const updatedBy = room.updatedBy === myUid ? 'you' : isHub ? 'room member' : 'partner';
  return (
    <div style={{ ...AppTypography.outfitWhite, fontSize: 11, color: Derived.textMuted }}>
      {`${formatPartyTime(seconds)} • Everglow Server • Updated by ${updatedBy}`}
    </div>
  );
}
