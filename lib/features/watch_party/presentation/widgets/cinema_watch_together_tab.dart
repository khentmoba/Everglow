import 'dart:async';

import 'package:flutter/material.dart';
import '../../../../shared/widgets/app_network_image.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../cinema/data/models/media_item.dart';
import '../../../cinema/presentation/widgets/netflix/netflix_colors.dart';
import '../../../cinema/presentation/widgets/netflix/netflix_nav_bar.dart';
import '../../../cinema/presentation/widgets/netflix/netflix_poster_card.dart';
import '../../../../core/services/auth_service.dart';
import '../../data/models/watch_party_room.dart';
import '../../data/services/watch_party_service.dart';
import '../screens/watch_party_screen.dart' deferred as watch_party_lib;
import 'start_watch_party_button.dart';
import 'temporary_chat_panel.dart';
part 'cinema_watch_together_widgets.dart';

/// Dedicated "Watch Together" tab inside Cinema.
///
/// Matches the Cinema shell (near-black stage, poster grid, rose accent)
/// while surfacing the couple's active party room and one-tap party
/// starters from the existing watchlist.
class CinemaWatchTogetherTab extends StatefulWidget {
  final List<MediaItem> watchlist;
  final void Function(MediaItem) onMediaTap;
  final void Function(int tab) onSwitchTab;

  const CinemaWatchTogetherTab({
    super.key,
    required this.watchlist,
    required this.onMediaTap,
    required this.onSwitchTab,
  });

  @override
  State<CinemaWatchTogetherTab> createState() => _CinemaWatchTogetherTabState();
}

class _CinemaWatchTogetherTabState extends State<CinemaWatchTogetherTab> {
  final WatchPartyService _service = WatchPartyService();
  Stream<WatchPartyRoom?>? _roomStream;
  String? _roomId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = context.read<AuthService>();
    final myUid = auth.uid;
    final partnerUid = auth.partnerUid;
    if (myUid != null && partnerUid != null) {
      _roomId ??= WatchPartyRoom.buildRoomId(myUid, partnerUid);
      final roomId = _roomId;
      if (roomId != null) {
        _roomStream ??= _service.getRoomStream(roomId);
      }
    }
  }

  /// Re-subscribes the room stream after a listener error (timeout or
  /// permission flap on web). The old stream already terminated, so a
  /// fresh one is the only way back to live updates.
  void _retryRoomStream() {
    final roomId = _roomId;
    if (roomId == null) return;
    setState(() {
      _roomStream = _service.getRoomStream(roomId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isCouple = context.watch<AuthService>().isCoupleUser;
    final auth = context.read<AuthService>();
    final isDesktop = MediaQuery.sizeOf(context).width >= 1024;
    final myUid = auth.uid;
    final partnerUid = auth.partnerUid;

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            isDesktop ? 48 : 16,
            cinemaTopContentInset(context),
            isDesktop ? 48 : 16,
            4,
          ),
          sliver: SliverToBoxAdapter(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Watch Together',
                        style: AppTypography.outfitHeading.copyWith(
                          fontSize: isDesktop ? 26 : 22,
                          color: NetflixColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isCouple
                            ? 'Start a movie night or resume what you were watching.'
                            : 'Available for the couple profile.',
                        style: AppTypography.outfitWhite.copyWith(
                          fontSize: 13,
                          color: NetflixColors.textMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isCouple)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: NetflixColors.accent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: NetflixColors.accent.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Text(
                      'COUPLE ONLY',
                      style: AppTypography.outfitHeading.copyWith(
                        fontSize: 9.5,
                        letterSpacing: 1.2,
                        color: NetflixColors.textPrimary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            isDesktop ? 48 : 16,
            18,
            isDesktop ? 48 : 16,
            0,
          ),
          sliver: SliverToBoxAdapter(
            child: _WatchTogetherStage(isEmpty: widget.watchlist.isEmpty),
          ),
        ),
        if (isCouple && myUid != null && partnerUid != null)
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              isDesktop ? 48 : 16,
              18,
              isDesktop ? 48 : 16,
              0,
            ),
            sliver: SliverToBoxAdapter(
              child: TemporaryChatPanel(
                roomId: WatchPartyRoom.buildRoomId(myUid, partnerUid),
                myUid: myUid,
                partnerUid: partnerUid,
              ),
            ),
          ),
        if (isCouple) ...[
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              isDesktop ? 48 : 16,
              18,
              isDesktop ? 48 : 16,
              0,
            ),
            sliver: SliverToBoxAdapter(
              child: StreamBuilder<WatchPartyRoom?>(
                stream: _roomStream,
                builder: (context, snap) {
                  if (snap.hasError) {
                    return _PartyErrorCard(onRetry: _retryRoomStream);
                  }
                  final room = snap.data;
                  if (room == null || !room.isLive()) {
                    return const _NoActivePartyCard();
                  }
                  return _ActivePartyCard(room: room);
                },
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              isDesktop ? 48 : 16,
              22,
              isDesktop ? 48 : 16,
              0,
            ),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  Text(
                    'Pick a title',
                    style: AppTypography.outfitHeading.copyWith(
                      fontSize: isDesktop ? 18 : 16,
                      color: NetflixColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${widget.watchlist.length} saved',
                    style: AppTypography.outfitWhite.copyWith(
                      fontSize: 12,
                      color: NetflixColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (widget.watchlist.isEmpty)
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                isDesktop ? 48 : 16,
                18,
                isDesktop ? 48 : 16,
                24,
              ),
              sliver: SliverToBoxAdapter(child: _buildEmptyWatchlist(context)),
            )
          else
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                isDesktop ? 48 : 16,
                14,
                isDesktop ? 48 : 16,
                20,
              ),
              sliver: SliverGrid(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _WatchTogetherPoster(
                    item: widget.watchlist[index],
                    onTap: () => widget.onMediaTap(widget.watchlist[index]),
                  ),
                  childCount: widget.watchlist.length,
                ),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 170,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: 2 / 3,
                ),
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildEmptyWatchlist(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: NetflixColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: NetflixColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.movie_filter_rounded,
            color: NetflixColors.gold,
            size: 28,
          ),
          const SizedBox(height: 10),
          Text(
            'Your list is empty',
            style: AppTypography.outfitHeading.copyWith(
              fontSize: 15,
              color: NetflixColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Add movies in Cinema or browse the My List tab, then start a party here.',
            style: AppTypography.outfitWhite.copyWith(
              fontSize: 12,
              color: NetflixColors.textMuted,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => widget.onSwitchTab(3),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: NetflixColors.accent.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: NetflixColors.accent.withValues(alpha: 0.55),
                ),
              ),
              child: Text(
                'Open My List',
                style: AppTypography.outfitBold.copyWith(
                  fontSize: 12,
                  color: NetflixColors.textPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
