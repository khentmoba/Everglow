import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:everglow/core/theme/app_typography.dart';
import 'package:everglow/features/cinema/data/models/media_item.dart';
import 'package:everglow/features/cinema/presentation/widgets/netflix/netflix_colors.dart';
import 'package:everglow/features/cinema/presentation/widgets/netflix/netflix_nav_bar.dart';
import 'package:everglow/features/cinema/presentation/widgets/netflix/netflix_poster_card.dart';
import 'package:everglow/features/jellyfin/data/models/jellyfin_media_item.dart';
import 'package:everglow/features/jellyfin/data/services/jellyfin_api_service.dart';
import 'package:everglow/services/auth_service.dart';
import '../../data/models/watch_party_room.dart';
import '../../data/services/temporary_chat_service.dart';
import '../../data/services/watch_party_chat_service.dart';
import '../../data/services/watch_party_service.dart';
import '../screens/watch_party_screen.dart';
import 'start_watch_party_button.dart';
import 'temporary_chat_panel.dart';

/// Dedicated "Watch Together" tab inside Cinema.
///
/// Matches the Cinema shell (near-black stage, poster grid, rose accent)
/// while surfacing the couple's active party room and one-tap party
/// starters from the existing watchlist. Self-hosted Jellyfin downloads
/// are reachable from here so the whole movie-night flow stays in one
/// place.
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
  State<CinemaWatchTogetherTab> createState() =>
      _CinemaWatchTogetherTabState();
}

class _CinemaWatchTogetherTabState extends State<CinemaWatchTogetherTab> {
  final WatchPartyService _service = WatchPartyService();
  final JellyfinApiService _jellyfin = const JellyfinApiService();
  Stream<WatchPartyRoom?>? _roomStream;

  List<JellyfinMediaItem> _jellyfinMovies = const [];
  bool _loadingJellyfin = true;
  String? _jellyfinError;

  @override
  void initState() {
    super.initState();
    _loadJellyfinLibrary();
  }

  Future<void> _loadJellyfinLibrary() async {
    setState(() {
      _loadingJellyfin = true;
      _jellyfinError = null;
    });
    if (!_jellyfin.hasConfiguredKey) {
      setState(() {
        _loadingJellyfin = false;
        _jellyfinMovies = const [];
        _jellyfinError = 'Jellyfin API key is not configured. '
            'Add JELLYFIN_API_KEY to assets/env.txt, then refresh.';
      });
      return;
    }
    final movies = await _jellyfin.fetchMovies();
    if (!mounted) return;
    setState(() {
      _loadingJellyfin = false;
      if (movies == null) {
        _jellyfinMovies = const [];
        _jellyfinError = 'Could not reach Jellyfin at '
            '${_jellyfin.baseUrl}. Make sure the server is running and the '
            'API key is valid, then refresh.';
      } else {
        _jellyfinMovies = movies;
        _jellyfinError = movies.isEmpty
            ? 'Jellyfin is running, but no movies are indexed yet. '
                'Add files to C:\\Users\\Admin\\Videos\\Movies and refresh.'
            : null;
      }
    });
  }

  Future<void> _startFromJellyfin(JellyfinMediaItem item) async {
    final auth = context.read<AuthService>();
    final myUid = auth.uid;
    final partnerUid = auth.partnerUid;
    if (myUid == null || partnerUid == null) return;

    final myName = auth.currentUser ?? '';
    final partnerName = auth.partnerName;
    final posterUrl = _jellyfin.posterUrlFor(item.id, tag: item.imageTag);
    final streamUrl = _jellyfin.streamUrlFor(item.id);
    final subtitleIndex =
        await _jellyfin.fetchDefaultSubtitleIndex(item.id);
    final subtitleUrl = subtitleIndex == null
        ? null
        : _jellyfin.subtitleUrlFor(item.id, subtitleIndex);

    try {
      final room = await _service.startRoom(
        hostUid: myUid,
        hostName: myName,
        partnerUid: partnerUid,
        partnerName: partnerName,
        mediaType: 'movie',
        tmdbId: 0,
        title: item.name,
        posterPath: posterUrl,
      );
      await _service.updateServer(
        roomId: room.id,
        serverType: 'hls',
        serverName: 'Jellyfin · ${item.name}',
        serverHost: 'jellyfin',
        streamUrl: streamUrl,
        subtitleUrl: subtitleUrl,
        updatedBy: myUid,
      );
      final roomWithServer = room
          .copyWithServer(
            serverType: 'hls',
            serverName: 'Jellyfin · ${item.name}',
            serverHost: 'jellyfin',
            streamUrl: streamUrl,
            subtitleUrl: subtitleUrl,
          )
          .copyWith(
            state: 'paused',
            currentTime: 0.0,
            updatedAt: DateTime.now(),
            updatedBy: myUid,
          );
      // A new movie night starts with a fresh conversation for both the
      // temporary Watch Together chat and the in-player party chat.
      await WatchPartyChatService().clearMessages(room.id);
      final tempService = TemporaryChatService();
      await tempService.ensureRoom(
        roomId: room.id,
        myUid: myUid,
        partnerUid: partnerUid,
      );
      await tempService.clearMessages(room.id);
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => WatchPartyScreen(
            initialRoom: roomWithServer,
            isHost: true,
          ),
        ),
      );
    } catch (e) {
      debugPrint('[WatchTogether] Failed to start Jellyfin party: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not start the party for ${item.name}'),
          backgroundColor: NetflixColors.accent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = context.read<AuthService>();
    final myUid = auth.uid;
    final partnerUid = auth.partnerUid;
    if (myUid != null && partnerUid != null) {
      _roomStream ??= _service.getRoomStream(
        WatchPartyRoom.buildRoomId(myUid, partnerUid),
      );
    }
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
            child: _WatchTogetherStage(
              isEmpty: widget.watchlist.isEmpty,
              onHost: () => context.go('/party-downloads'),
            ),
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
                  final room = snap.data;
                  if (room == null || !room.active) {
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
                  Expanded(
                    child: Text(
                      'Your Jellyfin Library',
                      style: AppTypography.outfitHeading.copyWith(
                        fontSize: isDesktop ? 18 : 16,
                        color: NetflixColors.textPrimary,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _loadJellyfinLibrary,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: NetflixColors.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: NetflixColors.hairline),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.refresh_rounded,
                            color: NetflixColors.textSecondary,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Refresh',
                            style: AppTypography.outfitBold.copyWith(
                              fontSize: 11.5,
                              color: NetflixColors.textPrimary,
                            ),
                          ),
                        ],
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
              14,
              isDesktop ? 48 : 16,
              20,
            ),
            sliver: SliverToBoxAdapter(child: _buildJellyfinLibrary()),
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
              sliver: SliverToBoxAdapter(
                child: _buildEmptyWatchlist(context),
              ),
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
                gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
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

  Widget _buildJellyfinLibrary() {
    if (_loadingJellyfin) {
      return Container(
        height: 180,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: NetflixColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: NetflixColors.hairline),
        ),
        child: const CircularProgressIndicator(
          color: NetflixColors.accent,
          strokeWidth: 2,
        ),
      );
    }

    if (_jellyfinError != null) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: NetflixColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: NetflixColors.hairline),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.dns_outlined,
              color: NetflixColors.textMuted,
              size: 28,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No movies available yet',
                    style: AppTypography.outfitBold.copyWith(
                      fontSize: 14,
                      color: NetflixColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _jellyfinError!,
                    style: AppTypography.outfitWhite.copyWith(
                      fontSize: 11.5,
                      color: NetflixColors.textMuted,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      height: 230,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _jellyfinMovies.length,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final movie = _jellyfinMovies[index];
          return _JellyfinMovieCard(
            movie: movie,
            posterUrl: _jellyfin.posterUrlFor(movie.id, tag: movie.imageTag),
            onTap: () => _startFromJellyfin(movie),
          );
        },
      ),
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
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 9,
              ),
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

class _NoActivePartyCard extends StatelessWidget {
  const _NoActivePartyCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: NetflixColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: NetflixColors.hairline),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: NetflixColors.accent.withValues(alpha: 0.18),
              shape: BoxShape.circle,
              border: Border.all(
                color: NetflixColors.accent.withValues(alpha: 0.55),
              ),
            ),
            child: const Icon(
              Icons.favorite_rounded,
              color: NetflixColors.accent,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No active movie night',
                  style: AppTypography.outfitBold.copyWith(
                    fontSize: 15,
                    color: NetflixColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Tap a poster below to start a synchronized party.',
                  style: AppTypography.outfitWhite.copyWith(
                    fontSize: 12,
                    color: NetflixColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivePartyCard extends StatelessWidget {
  final WatchPartyRoom room;

  const _ActivePartyCard({required this.room});

  String get _posterUrl {
    final path = room.posterPath;
    if (path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    return 'https://image.tmdb.org/t/p/w500$path';
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();
    final isHost = room.hostUid == auth.uid;
    final subtitle = room.mediaType == 'tv'
        ? 'S${room.season ?? 1} E${room.episode ?? 1}'
        : 'Movie';

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => WatchPartyScreen(
              initialRoom: room,
              isHost: isHost,
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: [NetflixColors.surfaceElevated, Color(0xFF1B1024)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: NetflixColors.gold.withValues(alpha: 0.45)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 22,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(16),
              ),
              child: _posterUrl.isEmpty
                  ? Container(
                      width: 96,
                      height: 136,
                      color: NetflixColors.surface,
                      child: const Icon(
                        Icons.movie_rounded,
                        color: NetflixColors.textMuted,
                        size: 34,
                      ),
                    )
                  : Image.network(
                      _posterUrl,
                      width: 96,
                      height: 136,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        width: 96,
                        height: 136,
                        color: NetflixColors.surface,
                        child: const Icon(
                          Icons.movie_rounded,
                          color: NetflixColors.textMuted,
                          size: 34,
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'MOVIE NIGHT',
                    style: AppTypography.outfitHeading.copyWith(
                      fontSize: 9.5,
                      letterSpacing: 1.4,
                      color: NetflixColors.gold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    room.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.cormorantBoldWhite.copyWith(
                      fontSize: 20,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$subtitle · ${isHost ? 'Hosting' : 'Joined'}',
                    style: AppTypography.outfitWhite.copyWith(
                      fontSize: 12,
                      color: NetflixColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [NetflixColors.accent, Color(0xFF8E1444)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isHost ? 'Resume party' : 'Join party',
                          style: AppTypography.outfitBold.copyWith(
                            fontSize: 12,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
          ],
        ),
      ),
    );
  }
}

class _WatchTogetherPoster extends StatelessWidget {
  final MediaItem item;
  final VoidCallback onTap;

  const _WatchTogetherPoster({
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        NetflixPosterCard(
          item: item,
          compact: true,
          onTap: onTap,
        ),
        Positioned(
          right: 6,
          bottom: 6,
          child: StartWatchPartyButton(
            variant: WatchPartyButtonVariant.icon,
            media: MediaRef(
              tmdbId: item.tmdbId,
              malId: item.isAnime ? item.tmdbId : null,
              mediaType: item.mediaType,
              isAnime: item.isAnime,
              season: item.currentSeason,
              episode: item.currentEpisode,
              title: item.title,
              posterPath: item.posterPath,
            ),
          ),
        ),
      ],
    );
  }
}

class _WatchTogetherStage extends StatelessWidget {
  final bool isEmpty;
  final VoidCallback onHost;

  const _WatchTogetherStage({
    required this.isEmpty,
    required this.onHost,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1C1624), Color(0xFF0A0710)],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: NetflixColors.hairline),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.45),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              NetflixColors.accent,
                              Color(0xFF8E1444),
                            ],
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: NetflixColors.accent.withValues(
                                alpha: 0.45,
                              ),
                              blurRadius: 22,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 34,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        isEmpty ? 'Ready for movie night' : 'Movie night ready',
                        style: AppTypography.cormorantBoldWhite.copyWith(
                          fontSize: 22,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        isEmpty
                            ? 'Pick a title below or host from Jellyfin.'
                            : 'Pick a title below to start the synchronized player.',
                        style: AppTypography.outfitWhite.copyWith(
                          fontSize: 12,
                          color: NetflixColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: NetflixColors.accent.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: NetflixColors.match,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'WATCH TOGETHER',
                          style: AppTypography.outfitHeading.copyWith(
                            fontSize: 8.5,
                            letterSpacing: 1.2,
                            color: NetflixColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        GestureDetector(
          onTap: onHost,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: NetflixColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: NetflixColors.hairline),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: NetflixColors.accent.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: NetflixColors.accent.withValues(alpha: 0.5),
                    ),
                  ),
                  child: const Icon(
                    Icons.dns_rounded,
                    color: NetflixColors.accent,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Server: Self-hosted Jellyfin',
                        style: AppTypography.outfitBold.copyWith(
                          fontSize: 14,
                          color: NetflixColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'HLS stream · real play/pause/seek sync, no ads',
                        style: AppTypography.outfitWhite.copyWith(
                          fontSize: 11.5,
                          color: NetflixColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_rounded,
                  color: NetflixColors.textPrimary,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _JellyfinMovieCard extends StatelessWidget {
  final JellyfinMediaItem movie;
  final String posterUrl;
  final VoidCallback onTap;

  const _JellyfinMovieCard({
    required this.movie,
    required this.posterUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final year = movie.year;
    final runtime = movie.runtimeMinutes;
    return SizedBox(
      width: 132,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    posterUrl,
                    width: 132,
                    height: 190,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      width: 132,
                      height: 190,
                      color: NetflixColors.surface,
                      child: const Icon(
                        Icons.movie_rounded,
                        color: NetflixColors.textMuted,
                        size: 40,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: NetflixColors.accent,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              movie.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.outfitBold.copyWith(
                fontSize: 12,
                height: 1.2,
                color: NetflixColors.textPrimary,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              [
                if (year != null && year.isNotEmpty) year,
                if (runtime > 0) '${runtime}m',
              ].join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.outfitWhite.copyWith(
                fontSize: 10.5,
                color: NetflixColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
