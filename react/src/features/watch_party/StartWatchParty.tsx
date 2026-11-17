// Port of lib/features/watch_party/presentation/widgets/start_watch_party_button.dart.
import { authService, useAuth } from '../../core/services/auth';
import { Logger } from '../../core/system/logger';
import { AppColors, withAlpha } from '../../core/theme/colors';
import { useSource } from '../../core/utils/liveSource';
import { Icon } from '../../shared/widgets/Icon';
import { showSnackBar } from '../../shared/widgets/SnackBar';
import { buildCoupleRoomId, clearTemporaryChat, ensureTemporaryChatRoom } from './temporaryChatService';
import {
  clearRoomChat,
  createWatchPartyRoom,
  getWatchPartyRooms,
  isRoomLive,
  roomsStream,
  updateRoomMedia,
  updateWatchPartyRoom,
  type MediaRef,
  type WatchPartyRoom,
} from './watchPartyService';

const sameMedia = (room: WatchPartyRoom, media: MediaRef) =>
  room.tmdbId === media.tmdbId &&
  room.malId === media.malId &&
  room.isAnime === media.isAnime &&
  room.season === media.season &&
  room.episode === media.episode;

/**
 * `startWatchParty`: reuse the live room (or the newest one), switching it to this
 * title when it differs, or make a fresh "Movie Night" / "Anime Night" room; then open it.
 */
export async function startWatchParty(media: MediaRef, openRoom: (roomId: string) => void): Promise<void> {
  const myUid = authService.uid;
  const partnerUid = authService.partnerUid;
  if (!myUid || !partnerUid) return;

  if (media.tmdbId === 0) {
    showSnackBar('Browse a title first to start a party.', { background: AppColors.deepRose });
    return;
  }

  let rooms: WatchPartyRoom[];
  try {
    rooms = await getWatchPartyRooms(myUid);
  } catch {
    showSnackBar('Could not load your rooms. Try again in a moment.');
    return;
  }
  const existing = rooms.find((r) => isRoomLive(r)) ?? rooms[0] ?? null;

  let roomId: string;
  let freshChat = false;
  if (existing) {
    roomId = existing.id;
    if (!sameMedia(existing, media)) {
      freshChat = true;
      await updateRoomMedia(existing.id, media, myUid);
    } else if (!isRoomLive(existing)) {
      await updateWatchPartyRoom(existing.id, { active: true, state: 'paused', updatedBy: myUid });
    }
  } else {
    const room = await createWatchPartyRoom({
      hostUid: myUid,
      hostName: authService.currentUser ?? '',
      partnerUid,
      partnerName: authService.partnerName,
      name: media.isAnime ? 'Anime Night' : 'Movie Night',
      media,
    });
    roomId = room.id;
    freshChat = true;
  }

  if (freshChat) {
    try {
      await clearRoomChat(roomId);
    } catch (e) {
      Logger.w(`SWP clear party chat failed: ${e}`);
    }
    try {
      const tempRoomId = buildCoupleRoomId(myUid, partnerUid);
      await ensureTemporaryChatRoom(tempRoomId, myUid, partnerUid);
      await clearTemporaryChat(tempRoomId);
    } catch (e) {
      Logger.w(`SWP clear temporary chat failed: ${e}`);
    }
  }
  openRoom(roomId);
}

/** `StartWatchPartyButton`: a 36px heart that turns into replay / swap when a party is already running. */
export function StartWatchPartyButton({ media, openRoom }: { media: MediaRef; openRoom: (roomId: string) => void }) {
  const auth = useAuth();
  const myUid = auth.uid && auth.partnerUid ? auth.uid : '';
  const rooms = useSource(() => (myUid ? roomsStream(myUid) : null), [myUid], [] as WatchPartyRoom[]);
  if (!auth.isCoupleUser) return null;
  const room = rooms.find((r) => r.active);
  const mediaDiffers = !!room && !sameMedia(room, media);
  const color = mediaDiffers ? AppColors.warmAmber : room ? AppColors.animeGold : AppColors.deepRose;
  return (
    <button
      type="button"
      className="bare-button"
      aria-label="Watch together"
      onClick={(e) => {
        e.stopPropagation();
        void startWatchParty(media, openRoom);
      }}
      style={{
        width: 36,
        height: 36,
        boxSizing: 'border-box',
        borderRadius: '50%',
        background: withAlpha(color, 0.25),
        border: `1.2px solid ${color}`,
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
      }}
    >
      <Icon name={mediaDiffers ? 'swap_horiz' : room ? 'replay' : 'favorite'} size={16} color={color} />
    </button>
  );
}
