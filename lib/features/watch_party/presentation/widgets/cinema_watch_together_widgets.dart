part of 'cinema_watch_together_tab.dart';

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

/// Shown when the room listener errors (hang, permission flap on web).
/// Retry builds a fresh stream: the failed one already terminated.
class _PartyErrorCard extends StatelessWidget {
  final VoidCallback onRetry;

  const _PartyErrorCard({required this.onRetry});

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
          const Icon(
            Icons.refresh_rounded,
            color: NetflixColors.textMuted,
            size: 28,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'Could not load the movie night. Check connection, then retry.',
              style: AppTypography.outfitWhite.copyWith(
                fontSize: 13,
                color: NetflixColors.textMuted,
              ),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
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
      onTap: () async {
        await watch_party_lib.loadLibrary();
        if (!context.mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => watch_party_lib.WatchPartyScreen(
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
                        colors: [NetflixColors.accent, AppColors.rosePressed],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.play_arrow_rounded,
                          color: AppColors.petalWhite,
                          size: 18,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isHost ? 'Resume party' : 'Join party',
                          style: AppTypography.outfitBold.copyWith(
                            fontSize: 12,
                            color: AppColors.petalWhite,
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

  const _WatchTogetherPoster({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        NetflixPosterCard(item: item, compact: true, onTap: onTap),
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

  const _WatchTogetherStage({required this.isEmpty, required this.onHost});

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
                              AppColors.rosePressed,
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
                          color: AppColors.petalWhite,
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

class _JellyfinSearchDialog extends StatefulWidget {
  final JellyfinApiService service;

  const _JellyfinSearchDialog({required this.service});

  @override
  State<_JellyfinSearchDialog> createState() => _JellyfinSearchDialogState();
}

class _JellyfinSearchDialogState extends State<_JellyfinSearchDialog> {
  final TextEditingController _query = TextEditingController();
  List<JellyfinMediaItem> _results = const [];
  bool _searching = false;
  bool _searched = false;
  String? _error;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _runSearch([String? value]) async {
    final text = (value ?? _query.text).trim();
    if (text.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _searching = true;
      _searched = true;
      _error = null;
    });
    final results = await widget.service.searchMovies(text);
    if (!mounted) return;
    setState(() {
      _searching = false;
      _results = results ?? const [];
      if (results == null) {
        _error =
            'Could not reach Jellyfin. Make sure the server is running '
            'and the API key is valid.';
      } else if (results.isEmpty) {
        _error = 'No movies found in the library for "$text".';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final dialogHeight = (MediaQuery.sizeOf(context).height * 0.8).clamp(
      320.0,
      440.0,
    );
    return Dialog(
      backgroundColor: NetflixColors.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: SizedBox(
        width: 540,
        height: dialogHeight.toDouble(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Search your directory',
                      style: AppTypography.outfitHeading.copyWith(
                        fontSize: 16,
                        color: NetflixColors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: NetflixColors.textMuted,
                    ),
                    tooltip: 'Close',
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
              child: TextField(
                controller: _query,
                autofocus: true,
                textInputAction: TextInputAction.search,
                onSubmitted: _runSearch,
                style: AppTypography.outfitWhite.copyWith(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search Jellyfin movies by title or file name',
                  hintStyle: AppTypography.outfitWhite.copyWith(
                    fontSize: 13,
                    color: NetflixColors.textMuted,
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: NetflixColors.accent,
                  ),
                  suffixIcon: _searching
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: NetflixColors.accent,
                            ),
                          ),
                        )
                      : IconButton(
                          onPressed: _runSearch,
                          icon: const Icon(
                            Icons.arrow_forward_rounded,
                            color: NetflixColors.accent,
                          ),
                          tooltip: 'Search',
                        ),
                  filled: true,
                  fillColor: NetflixColors.surface.withValues(alpha: 0.6),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: NetflixColors.hairline.withValues(alpha: 0.8),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: NetflixColors.hairline.withValues(alpha: 0.8),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: NetflixColors.accent),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: _buildBody(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_searching) {
      return const Center(
        child: CircularProgressIndicator(
          color: NetflixColors.accent,
          strokeWidth: 2,
        ),
      );
    }
    if (_error != null) {
      return _buildMessage(_error!, Icons.search_off_rounded);
    }
    if (!_searched) {
      return _buildMessage(
        'Search the movies Jellyfin has indexed from your library folders.',
        Icons.folder_open_rounded,
      );
    }
    if (_results.isEmpty) {
      return _buildMessage(
        'Nothing found yet. Try another title.',
        Icons.movie_filter_rounded,
      );
    }
    return ListView.separated(
      itemCount: _results.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final movie = _results[index];
        final year = movie.year;
        final runtime = movie.runtimeMinutes;
        return GestureDetector(
          onTap: () => Navigator.of(context).pop(movie),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: NetflixColors.surface.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: NetflixColors.hairline),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.network(
                    widget.service.posterUrlFor(movie.id, tag: movie.imageTag),
                    width: 48,
                    height: 68,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      width: 48,
                      height: 68,
                      color: NetflixColors.surface,
                      child: const Icon(
                        Icons.movie_rounded,
                        color: NetflixColors.textMuted,
                        size: 22,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        movie.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.outfitBold.copyWith(
                          fontSize: 13,
                          height: 1.25,
                          color: NetflixColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        [
                          if (year != null && year.isNotEmpty) year,
                          if (runtime > 0) '${runtime}m',
                        ].join(' · '),
                        style: AppTypography.outfitWhite.copyWith(
                          fontSize: 11,
                          color: NetflixColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.play_circle_fill_rounded,
                  color: NetflixColors.accent,
                  size: 28,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMessage(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: NetflixColors.textMuted, size: 34),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: AppTypography.outfitWhite.copyWith(
                fontSize: 12.5,
                height: 1.4,
                color: NetflixColors.textMuted,
              ),
            ),
          ),
        ],
      ),
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
                      color: AppColors.petalWhite,
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
