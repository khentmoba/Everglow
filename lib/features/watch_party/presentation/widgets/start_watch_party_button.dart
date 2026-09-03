import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/auth_service.dart';
import '../../data/models/watch_party_room.dart';
import '../../data/services/watch_party_service.dart';
import '../../data/services/watch_party_chat_service.dart';
import '../../data/services/temporary_chat_service.dart';
import '../screens/watch_party_screen.dart' deferred as watch_party_lib;
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_colors.dart';

const _cDeepRose = AppColors.deepRose;
const _cGold = AppColors.animeGold;
const _cAmber = AppColors.warmAmber;
const _cVelvet = AppColors.deepBlack;
const _cWhite = AppColors.petalWhite;

/// Compact "Watch Together" button. Tap to start (or join) a watch
/// party. Renders differently depending on whether a party is already
/// active for this couple — gold "Resume" pill instead of the default
/// rose "Start" button.
///
/// Used in three places:
///   * Episode drawer — movie: a secondary CTA next to the play button.
///   * Episode drawer — TV: an overlay icon on the episode tile.
///   * Dashboard — the "Watch Together" shelf card.
class StartWatchPartyButton extends StatefulWidget {
  /// The media this button represents. Required for "Start" — we
  /// need to know which movie/episode to open when the host taps.
  final MediaRef media;

  /// Visual variant. 'pill' for in-line placement on a drawer/episode
  /// tile, 'card' for the dashboard tile, 'icon' for a minimal
  /// floating action.
  final WatchPartyButtonVariant variant;

  /// Compact label override. `null` picks a sensible default based on
  /// the variant.
  final String? labelOverride;

  const StartWatchPartyButton({
    super.key,
    required this.media,
    this.variant = WatchPartyButtonVariant.pill,
    this.labelOverride,
  });

  @override
  State<StartWatchPartyButton> createState() => _StartWatchPartyButtonState();
}

enum WatchPartyButtonVariant { pill, card, icon }

/// Minimal subset of [MediaItem] we need to start a party. The episode
/// drawer has the full MediaItem; the dashboard card may not, so we
/// accept this smaller bundle instead.
class MediaRef {
  final int tmdbId;
  final int? malId;
  final String mediaType; // 'movie' | 'tv'
  final bool isAnime;
  final int? season;
  final int? episode;
  final String title;
  final String posterPath;

  const MediaRef({
    required this.tmdbId,
    this.malId,
    required this.mediaType,
    this.isAnime = false,
    this.season,
    this.episode,
    required this.title,
    this.posterPath = '',
  });
}

class _StartWatchPartyButtonState extends State<StartWatchPartyButton> {
  late final WatchPartyService _service;
  Stream<WatchPartyRoom?>? _activeStream;

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
      final roomId = WatchPartyRoom.buildRoomId(myUid, partnerUid);
      _activeStream = _service.getRoomStream(roomId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    if (!auth.isCoupleUser) {
      // Cinema-only profiles (Breyan, Octagram) can't host a party.
      return const SizedBox.shrink();
    }
    return StreamBuilder<WatchPartyRoom?>(
      stream: _activeStream,
      builder: (context, snap) {
        final room = snap.data;
        final hasActiveParty = room != null && room.active;
        final mediaDiffers =
            hasActiveParty &&
            (room.tmdbId != widget.media.tmdbId ||
                room.season != widget.media.season ||
                room.episode != widget.media.episode);
        switch (widget.variant) {
          case WatchPartyButtonVariant.pill:
            return _buildPill(context, hasActiveParty, mediaDiffers, room);
          case WatchPartyButtonVariant.card:
            return _buildCard(context, hasActiveParty, mediaDiffers, room);
          case WatchPartyButtonVariant.icon:
            return _buildIcon(context, hasActiveParty, mediaDiffers, room);
        }
      },
    );
  }

  // ─── Variants ─────────────────────────────────────────────────────

  Widget _buildPill(
    BuildContext context,
    bool hasParty,
    bool mediaDiffers,
    WatchPartyRoom? room,
  ) {
    final label =
        widget.labelOverride ??
        (mediaDiffers
            ? 'Switch to this'
            : hasParty
            ? 'Resume Night'
            : 'Watch Together');
    return GestureDetector(
      onTap: () => _onTap(context, hasParty, room),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: hasParty
              ? _cGold.withValues(alpha: 0.18)
              : _cDeepRose.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: hasParty
                ? _cGold.withValues(alpha: 0.6)
                : _cDeepRose.withValues(alpha: 0.6),
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              mediaDiffers
                  ? Icons.swap_horiz_rounded
                  : hasParty
                  ? Icons.replay_rounded
                  : Icons.favorite_rounded,
              color: mediaDiffers
                  ? _cAmber
                  : hasParty
                  ? _cGold
                  : _cDeepRose,
              size: 16,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTypography.outfitWhite.copyWith(
                color: _cWhite,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(
    BuildContext context,
    bool hasParty,
    bool mediaDiffers,
    WatchPartyRoom? room,
  ) {
    final iconColor = mediaDiffers
        ? _cAmber
        : hasParty
        ? _cGold
        : _cDeepRose;
    final label = mediaDiffers
        ? 'Switch'
        : hasParty
        ? 'Resume'
        : 'Start';
    return GestureDetector(
      onTap: () => _onTap(context, hasParty, room),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: hasParty
                ? [
                    iconColor.withValues(alpha: 0.20),
                    _cDeepRose.withValues(alpha: 0.12),
                  ]
                : [
                    _cDeepRose.withValues(alpha: 0.18),
                    _cVelvet.withValues(alpha: 0.6),
                  ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: iconColor.withValues(alpha: 0.6),
            width: 1.2,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_cDeepRose, AppColors.rosePressed],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: _cDeepRose.withValues(alpha: 0.4),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                mediaDiffers
                    ? Icons.swap_horiz_rounded
                    : hasParty
                    ? Icons.movie_filter_rounded
                    : Icons.favorite_rounded,
                color: AppColors.petalWhite,
                size: 28,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mediaDiffers
                        ? 'Switch movie'
                        : hasParty
                        ? 'Watching now'
                        : 'Movie Night',
                    style: AppTypography.cormorantExtraBold.copyWith(
                      fontSize: 18,
                      color: _cWhite,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    mediaDiffers
                        ? 'Tap to switch to ${widget.media.title}'
                        : hasParty
                        ? (room?.title ?? 'Resuming your party…')
                        : 'Watch a film in real time with your love',
                    style: AppTypography.outfitWhite.copyWith(
                      color: _cWhite.withValues(alpha: 0.7),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: iconColor, width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: AppTypography.outfitWhite.copyWith(
                      color: iconColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_forward_rounded, color: iconColor, size: 14),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIcon(
    BuildContext context,
    bool hasParty,
    bool mediaDiffers,
    WatchPartyRoom? room,
  ) {
    final iconColor = mediaDiffers
        ? _cAmber
        : hasParty
        ? _cGold
        : _cDeepRose;
    return GestureDetector(
      onTap: () => _onTap(context, hasParty, room),
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

  // ─── Tap handler ──────────────────────────────────────────────────

  Future<void> _onTap(
    BuildContext context,
    bool hasParty,
    WatchPartyRoom? room,
  ) async {
    HapticFeedback.selectionClick();
    final auth = context.read<AuthService>();
    final myUid = auth.uid;
    final partnerUid = auth.partnerUid;
    if (myUid == null || partnerUid == null) return;
    final myName = auth.currentUser ?? '';
    final partnerName = auth.partnerName;

    WatchPartyRoom toOpen;
    bool isHost;
    bool freshChat = false;
    debugPrint(
      'SWP _onTap: hasParty=$hasParty, media.tmdbId=${widget.media.tmdbId}, room.tmdbId=${room?.tmdbId}',
    );
    if (hasParty && room != null) {
      // Check if user is picking a different movie/episode.
      // A tmdbId of 0 means the button was built from a dummy MediaRef
      // (e.g. the dashboard card) — in that case we should never switch
      // the room to the dummy id.
      final mediaChanged =
          widget.media.tmdbId != 0 &&
          (room.tmdbId != widget.media.tmdbId ||
              room.season != widget.media.season ||
              room.episode != widget.media.episode);
      if (mediaChanged) {
        freshChat = true;
        await _service.updateMedia(
          roomId: room.id,
          mediaType: widget.media.mediaType,
          tmdbId: widget.media.tmdbId,
          malId: widget.media.malId,
          isAnime: widget.media.isAnime,
          season: widget.media.season,
          episode: widget.media.episode,
          title: widget.media.title,
          posterPath: widget.media.posterPath,
          updatedBy: myUid,
        );
        toOpen = WatchPartyRoom(
          id: room.id,
          hostUid: room.hostUid,
          hostName: room.hostName,
          partnerUid: room.partnerUid,
          partnerName: room.partnerName,
          mediaType: widget.media.mediaType,
          tmdbId: widget.media.tmdbId,
          malId: widget.media.malId,
          isAnime: widget.media.isAnime,
          season: widget.media.season,
          episode: widget.media.episode,
          title: widget.media.title,
          posterPath: widget.media.posterPath,
          state: 'paused',
          currentTime: 0.0,
          updatedAt: DateTime.now(),
          updatedBy: myUid,
          createdAt: room.createdAt,
          active: true,
        );
        isHost = room.hostUid == myUid;
      } else {
        toOpen = room;
        isHost = room.hostUid == myUid;
      }
    } else {
      if (widget.media.tmdbId == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Browse a title first to start a party.',
              style: AppTypography.outfitWhite.copyWith(color: AppColors.petalWhite),
            ),
            backgroundColor: _cDeepRose,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        return;
      }
      toOpen = await _service.startRoom(
        hostUid: myUid,
        hostName: myName,
        partnerUid: partnerUid,
        partnerName: partnerName,
        mediaType: widget.media.mediaType,
        tmdbId: widget.media.tmdbId,
        malId: widget.media.malId,
        isAnime: widget.media.isAnime,
        season: widget.media.season,
        episode: widget.media.episode,
        title: widget.media.title,
        posterPath: widget.media.posterPath,
      );
      isHost = true;
      freshChat = true;
    }

    if (freshChat) {
      // Each movie night starts with a clean conversation. Both the
      // in-player chat and the Watch Together temporary chat share the
      // couple's room id, so clearing here refreshes both surfaces.
      try {
        await WatchPartyChatService().clearMessages(toOpen.id);
      } catch (e) {
        debugPrint('SWP clear party chat failed: $e');
      }
      try {
        final tempService = TemporaryChatService();
        await tempService.ensureRoom(
          roomId: toOpen.id,
          myUid: myUid,
          partnerUid: partnerUid,
        );
        await tempService.clearMessages(toOpen.id);
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
}
