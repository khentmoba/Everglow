import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/auth_service.dart';
import '../../data/models/media_ref.dart';
import '../../data/models/watch_party_room.dart';
import '../../data/services/watch_party_service.dart';
import '../../data/services/watch_party_chat_service.dart';
import '../../data/services/temporary_chat_service.dart';
import '../screens/watch_party_screen.dart' deferred as watch_party_lib;
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_colors.dart';

export '../../data/models/media_ref.dart';

/// Starts a party for [media] (or switches the running one to it) and
/// opens the player.
///
/// Every entry point funnels through here: the poster buttons, the
/// dashboard card, and the Watch Together tab's own title picker. Keeping
/// one implementation is what stopped those surfaces from drifting —
/// the tab used to have its own private copy of this logic, which is how
/// it ended up unable to start a party from a searched title.
///
/// If a room is already live and [media] is a different title, the room
/// is switched in place so the partner's client follows. Otherwise the
/// most recent room is reused, or a new named room is created.
Future<void> startWatchParty(BuildContext context, MediaRef media) async {
  final auth = context.read<AuthService>();
  final myUid = auth.uid;
  final partnerUid = auth.partnerUid;
  if (myUid == null || partnerUid == null) return;

  if (media.tmdbId == 0) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Browse a title first to start a party.',
          style: AppTypography.outfitWhite.copyWith(
            color: AppColors.petalWhite,
          ),
        ),
        backgroundColor: AppColors.deepRose,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
    return;
  }

  final service = WatchPartyService();
  List<WatchPartyRoom> rooms;
  try {
    rooms = await service.getRooms(myUid);
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Could not load your rooms. Try again in a moment.'),
      ),
    );
    return;
  }
  final live = rooms.where((room) => room.isLive()).toList();
  final existing = live.isNotEmpty
      ? live.first
      : (rooms.isNotEmpty ? rooms.first : null);

  WatchPartyRoom toOpen;
  bool isHost;
  bool freshChat = false;

  if (existing != null) {
    final mediaChanged =
        existing.tmdbId != media.tmdbId ||
        existing.malId != media.malId ||
        existing.isAnime != media.isAnime ||
        existing.season != media.season ||
        existing.episode != media.episode;
    if (mediaChanged) {
      freshChat = true;
      await service.updateMedia(
        roomId: existing.id,
        mediaType: media.mediaType,
        tmdbId: media.tmdbId,
        malId: media.malId,
        isAnime: media.isAnime,
        season: media.season,
        episode: media.episode,
        episodeCount: media.episodeCount,
        title: media.title,
        posterPath: media.posterPath,
        updatedBy: myUid,
      );
      toOpen = existing
          .copyWithMedia(
            mediaType: media.mediaType,
            tmdbId: media.tmdbId,
            malId: media.malId,
            isAnime: media.isAnime,
            season: media.season,
            episode: media.episode,
            episodeCount: media.episodeCount,
            title: media.title,
            posterPath: media.posterPath,
            state: 'paused',
            currentTime: 0.0,
            positionAt: DateTime.now(),
            updatedAt: DateTime.now(),
            updatedBy: myUid,
            active: true,
          )
          .copyWithServer(
            serverType: 'everglow',
            serverName: 'Everglow',
            serverHost: 'everglow',
          );
    } else {
      toOpen = existing;
      if (!existing.isLive()) {
        await service.reopenRoom(roomId: existing.id, updatedBy: myUid);
        toOpen = existing.copyWith(
          active: true,
          state: 'paused',
          updatedAt: DateTime.now(),
          updatedBy: myUid,
        );
      }
    }
    isHost = existing.hostUid == myUid;
  } else {
    toOpen = await service.createRoom(
      hostUid: myUid,
      hostName: auth.currentUser ?? '',
      partnerUid: partnerUid,
      partnerName: auth.partnerName,
      name: media.isAnime ? 'Anime Night' : 'Movie Night',
      mediaType: media.mediaType,
      tmdbId: media.tmdbId,
      malId: media.malId,
      isAnime: media.isAnime,
      season: media.season,
      episode: media.episode,
      episodeCount: media.episodeCount,
      title: media.title,
      posterPath: media.posterPath,
    );
    isHost = true;
    freshChat = true;
  }

  if (freshChat) {
    // Each movie night starts with a clean conversation. The in-player
    // chat is scoped to the room (now an auto id); the Watch Together
    // temporary chat keeps the couple's deterministic id so it survives
    // room changes.
    try {
      await WatchPartyChatService().clearMessages(toOpen.id);
    } catch (e) {
      debugPrint('SWP clear party chat failed: $e');
    }
    try {
      final tempService = TemporaryChatService();
      final tempRoomId = WatchPartyRoom.buildRoomId(myUid, partnerUid);
      await tempService.ensureRoom(
        roomId: tempRoomId,
        myUid: myUid,
        partnerUid: partnerUid,
      );
      await tempService.clearMessages(tempRoomId);
    } catch (e) {
      debugPrint('SWP clear temporary chat failed: $e');
    }
  }

  if (!context.mounted) return;
  await watch_party_lib.loadLibrary();
  if (!context.mounted) return;
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => watch_party_lib.WatchPartyScreen(
        initialRoom: toOpen,
        isHost: isHost,
      ),
    ),
  );
}

/// Compact "Watch Together" button used on poster tiles. Tap to start
/// (or join) a watch party. Gold "Resume" when a party is already live
/// for this couple; rose "Start" otherwise.
class StartWatchPartyButton extends StatefulWidget {
  /// The media this button represents. Required for "Start" — we
  /// need to know which movie/episode to open when the host taps.
  final MediaRef media;

  const StartWatchPartyButton({super.key, required this.media});

  @override
  State<StartWatchPartyButton> createState() => _StartWatchPartyButtonState();
}

class _StartWatchPartyButtonState extends State<StartWatchPartyButton> {
  late final WatchPartyService _service;
  Stream<List<WatchPartyRoom>>? _roomsStream;

  @override
  void initState() {
    super.initState();
    _service = WatchPartyService();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = context.read<AuthService>();
    final myUid = auth.uid;
    final partnerUid = auth.partnerUid;
    if (myUid != null && partnerUid != null) {
      _roomsStream = _service.getRoomsStream(myUid);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCoupleUser =
        context.select<AuthService, bool>((a) => a.isCoupleUser);
    if (!isCoupleUser) {
      // Cinema-only profiles (Breyan, Octagram) can't host a party.
      return const SizedBox.shrink();
    }
    return StreamBuilder<List<WatchPartyRoom>>(
      stream: _roomsStream,
      builder: (context, snap) {
        final rooms = snap.data ?? const <WatchPartyRoom>[];
        WatchPartyRoom? room;
        for (final candidate in rooms) {
          if (candidate.active) {
            room = candidate;
            break;
          }
        }
        final hasActiveParty = room != null;
        final mediaDiffers =
            hasActiveParty &&
            (room.tmdbId != widget.media.tmdbId ||
                room.malId != widget.media.malId ||
                room.isAnime != widget.media.isAnime ||
                room.season != widget.media.season ||
                room.episode != widget.media.episode);
        return _buildIcon(context, hasActiveParty, mediaDiffers);
      },
    );
  }

  Widget _buildIcon(
    BuildContext context,
    bool hasParty,
    bool mediaDiffers,
  ) {
    final iconColor = mediaDiffers
        ? AppColors.warmAmber
        : hasParty
        ? AppColors.animeGold
        : AppColors.deepRose;
    return GestureDetector(
      onTap: () => _onTap(context),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.25),
          shape: BoxShape.circle,
          border: Border.all(color: iconColor, width: 1.2),
        ),
        child: Icon(
          mediaDiffers
              ? Icons.swap_horiz_rounded
              : hasParty
              ? Icons.replay_rounded
              : Icons.favorite_rounded,
          color: iconColor,
          size: 16,
        ),
      ),
    );
  }

  Future<void> _onTap(BuildContext context) async {
    HapticFeedback.selectionClick();
    return startWatchParty(context, widget.media);
  }
}
