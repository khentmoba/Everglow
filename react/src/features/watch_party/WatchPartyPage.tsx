// Port of lib/features/watch_party/presentation/screens/watch_party_lobby_screen.dart
// and watch_party_screen_web.dart.
import { EverglowFeatureHeader } from '../../shared/widgets/EverglowFeatureHeader';
import { useEffect, useState } from 'react';
import { useNavigate, useSearchParams } from 'react-router';
import { useAuth } from '../../core/services/auth';
import { useViewport } from '../../core/system/viewport';
import { AppColors, Derived, withAlpha } from '../../core/theme/colors';
import { AppRadius, AppSpacing } from '../../core/theme/layout';
import { Align, boxShadow, linear } from '../../core/theme/paint';
import { AppTypography } from '../../core/theme/typography';
import { useSource } from '../../core/utils/liveSource';
import { Icon } from '../../shared/widgets/Icon';
import { showSnackBar } from '../../shared/widgets/SnackBar';
import { TmdbImages, type MediaItem } from '../cinema/cinemaTypes';
import { searchMulti } from '../cinema/tmdbService';
import {
  createWatchPartyRoom,
  deleteWatchPartyRoom,
  formatPartyTime,
  isRoomLive,
  roomChatStream,
  roomStream,
  roomsStream,
  sendRoomChatMessage,
  updateWatchPartyRoom,
  type WatchPartyRoom,
} from './watchPartyService';

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

  if (activeRoomId) {
    return (
      <WatchPartyRoomView
        roomId={activeRoomId}
        myUid={myUid}
        myName={auth.currentUser ?? 'Khent'}
        onExit={() => ((window.history.state?.idx ?? 0) > 0 ? navigate(-1) : navigate('/watch-party', { replace: true }))}
      />
    );
  }

  return (
    <div style={{ position: 'fixed', inset: 0, background: AppColors.inkDeep, display: 'flex', flexDirection: 'column' }}>
      <EverglowFeatureHeader
        title="Watch Together"
        subtitle="pick a room, press play"
        icon="live_tv"
        hue={AppColors.auroraRose}
      />

      <div
        className="no-scrollbar"
        style={{
          flex: 1,
          overflowY: 'auto',
          padding: `${AppSpacing.lg}px ${AppSpacing.xl}px ${AppSpacing.x3}px`,
          width: '100%',
        }}
      >
        <WatchPartyLobby />
      </div>
    </div>
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
            <span style={{ ...AppTypography.outfitWhite, fontSize: 11, color: withAlpha(AppColors.petalWhite, 0.72) }}>
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
                    onContextMenu={(e) => {
                      e.preventDefault();
                      void deleteWatchPartyRoom(room.id);
                    }}
                    style={{
                      padding: 10,
                      background: Derived.surfaceGlass,
                      borderRadius: AppRadius.md,
                      border: `1px solid ${live ? withAlpha(AppColors.deepRose, 0.55) : Derived.border}`,
                      display: 'flex',
                      alignItems: 'center',
                      gap: 12,
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
  myUid,
  myName,
  onExit,
}: {
  roomId: string;
  myUid: string;
  myName: string;
  onExit: () => void;
}) {
  const { width } = useViewport();
  const room = useSource(() => roomStream(roomId), [roomId], null);
  const messages = useSource(() => roomChatStream(roomId), [roomId], []);
  const [chatOpen, setChatOpen] = useState(false);
  const [pickerOpen, setPickerOpen] = useState(false);
  const [msgText, setMsgText] = useState('');
  const [searchQ, setSearchQ] = useState('');
  const [searchResults, setSearchResults] = useState<MediaItem[]>([]);

  useEffect(() => {
    const q = searchQ.trim();
    if (!q) {
      setSearchResults([]);
      return;
    }
    const t = window.setTimeout(() => {
      void searchMulti(q).then((r) => setSearchResults(r.results));
    }, 300);
    return () => clearTimeout(t);
  }, [searchQ]);

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

  const compact = width < 700;
  const hasMedia = room.tmdbId > 0 || room.title.length > 0;
  const embedSrc = hasMedia
    ? room.isAnime
      ? `https://everglow-1c6db.web.app/embed.html?source=megaplay&malId=${room.malId ?? room.tmdbId}&ep=${room.episode ?? 1}`
      : `https://everglow-1c6db.web.app/embed.html?source=cinema&type=${room.mediaType}&tmdbId=${room.tmdbId}${room.mediaType === 'tv' ? `&s=${room.season ?? 1}&e=${room.episode ?? 1}` : ''}&title=${encodeURIComponent(room.title)}`
    : '';

  const togglePlay = () =>
    void updateWatchPartyRoom(room.id, {
      state: room.state === 'playing' ? 'paused' : 'playing',
      updatedBy: myUid,
    });

  const pickMedia = (m: MediaItem) => {
    void updateWatchPartyRoom(room.id, {
      tmdbId: m.tmdbId,
      mediaType: m.mediaType === 'tv' ? 'tv' : 'movie',
      title: m.title,
      posterPath: m.posterPath,
      isAnime: m.isAnime,
      season: m.mediaType === 'tv' ? 1 : undefined,
      episode: m.mediaType === 'tv' ? 1 : undefined,
      currentTime: 0,
      state: 'paused',
      updatedBy: myUid,
    });
    setPickerOpen(false);
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
            {hasMedia ? room.title : 'Pick a title'}
          </div>
        </div>
        <button
          type="button"
          className="bare-button"
          onClick={() => setPickerOpen(true)}
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
                  Pick a movie, series, or anime for both of you.
                </div>
                <div style={{ height: 16 }} />
                <button
                  type="button"
                  className="bare-button"
                  onClick={() => setPickerOpen(true)}
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
                <iframe
                  key={embedSrc}
                  src={embedSrc}
                  title={room.title}
                  allowFullScreen
                  allow="autoplay; fullscreen; picture-in-picture; encrypted-media"
                  sandbox="allow-scripts allow-same-origin allow-forms allow-presentation"
                  style={{ width: '100%', height: '100%', border: 'none', display: 'block' }}
                />
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
                  gap: 12,
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
                <div style={{ flex: 1 }}>
                  <div style={{ ...AppTypography.outfitBold, fontSize: 13, color: AppColors.petalWhite }}>
                    {room.state === 'playing' ? 'Synced Playback: Playing' : 'Synced Playback: Paused'}
                  </div>
                  <div style={{ ...AppTypography.outfitWhite, fontSize: 11, color: Derived.textMuted }}>
                    {`${formatPartyTime(room.currentTime)} • Updated by ${room.updatedBy === myUid ? 'you' : 'partner'}`}
                  </div>
                </div>
                <button
                  type="button"
                  className="bare-button"
                  onClick={() =>
                    void updateWatchPartyRoom(room.id, {
                      currentTime: Math.max(0, room.currentTime + 15),
                      updatedBy: myUid,
                    })
                  }
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
                  <div style={{ fontSize: 10, color: Derived.textMuted, marginBottom: 2 }}>{m.senderName}</div>
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
                    void sendRoomChatMessage(room.id, myUid, myName, msgText);
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
                    void sendRoomChatMessage(room.id, myUid, myName, msgText);
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

      {pickerOpen && (
        <div
          onClick={() => setPickerOpen(false)}
          style={{
            position: 'fixed',
            inset: 0,
            background: withAlpha(AppColors.inkDeep, 0.78),
            zIndex: 1100,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            padding: 16,
          }}
        >
          <div
            onClick={(e) => e.stopPropagation()}
            style={{
              width: '100%',
              maxWidth: 460,
              maxHeight: '80vh',
              borderRadius: 20,
              background: AppColors.inkDeep,
              border: `1px solid ${Derived.border}`,
              padding: 16,
              display: 'flex',
              flexDirection: 'column',
              gap: 12,
            }}
          >
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
              <span style={{ ...AppTypography.cormorantBoldWhite, fontSize: 22 }}>Choose a Title</span>
              <button type="button" className="bare-button" onClick={() => setPickerOpen(false)}>
                <Icon name="close" size={20} color={AppColors.petalWhite} />
              </button>
            </div>
            <input
              autoFocus
              value={searchQ}
              onChange={(e) => setSearchQ(e.target.value)}
              placeholder="Search movies or series…"
              style={{
                padding: '10px 12px',
                borderRadius: 12,
                background: AppColors.shimmerBase,
                border: `1px solid ${Derived.border}`,
                color: AppColors.petalWhite,
                outline: 'none',
              }}
            />
            <div
              className="no-scrollbar"
              style={{ flex: 1, overflowY: 'auto', display: 'flex', flexDirection: 'column', gap: 8 }}
            >
              {searchResults.map((m) => (
                <button
                  key={`${m.mediaType}:${m.tmdbId}`}
                  type="button"
                  className="bare-button"
                  onClick={() => pickMedia(m)}
                  style={{
                    padding: '10px 12px',
                    borderRadius: 10,
                    background: AppColors.shimmerBase,
                    textAlign: 'left',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'space-between',
                  }}
                >
                  <span style={{ ...AppTypography.outfitBold, fontSize: 13.5, color: AppColors.petalWhite }}>{m.title}</span>
                  <span style={{ fontSize: 11, color: Derived.textMuted }}>{m.mediaType.toUpperCase()}</span>
                </button>
              ))}
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
