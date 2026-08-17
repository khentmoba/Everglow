part of 'episode_drawer.dart';

abstract class _EpisodeDrawerStateCore2 extends _EpisodeDrawerStateCore {
  Future<void> _updateStatus(String newStatus) async {
    // Guard against rapid double-taps that would race.
    if (_isUpdatingStatus) {
      Logger.d("[Status] Ignoring — update already in progress");
      return;
    }
    _isUpdatingStatus = true;
    try {
      await _doUpdateStatus(newStatus);
    } finally {
      _isUpdatingStatus = false;
    }
  }

  Future<void> _doUpdateStatus(String newStatus) async {
    HapticFeedback.selectionClick();
    final auth = context.read<AuthService>();
    final userName = auth.currentUser ?? '';
    final partnerUsername = auth.partnerUsername;
    Logger.d(
      "[Status] _updateStatus called: newStatus=$newStatus, userName=$userName, currentItemStatus=${widget.item.status}, currentLocalStatus=$_currentStatus, tmdbId=${widget.item.tmdbId}, isAnime=${widget.item.isAnime}, mediaType=${widget.item.mediaType}, mounted=$mounted",
    );
    if (userName.isEmpty) {
      _showSnack('Please sign in to manage your watchlist');
      return;
    }
    // Save the previous status so we can revert locally if the Firestore
    // write fails. Without this, a network error in isAnimeByTmdbId or
    // saveToWatchList would leave the chip highlighted (from the early
    // setState) while the document in Firestore still has the old status —
    // making the change appear to "revert" the next time the stream fires.
    final previousStatus = _currentStatus;

    if (_currentStatus == newStatus) {
      // Tapping the already-selected chip → remove from watchlist.
      Logger.d("[Status] Same status tapped — removing from watchlist");
      setState(() => _currentStatus = '');
      try {
        await _tmdbService.removeFromWatchList(widget.item.tmdbId, userName);
        // For "Both" statuses, also remove from the partner's doc.
        if (previousStatus == 'watched-both' ||
            previousStatus == 'watching-both') {
          if (partnerUsername != null && partnerUsername.isNotEmpty) {
            Logger.d(
              "[Status] Both status — also removing from partner $partnerUsername",
            );
            try {
              await _tmdbService.removeFromWatchList(
                widget.item.tmdbId,
                partnerUsername,
              );
            } catch (e) {
              Logger.e("[Status] Failed to remove from partner", error: e);
            }
          }
        }
        Logger.d("[Status] Remove succeeded");
        if (mounted) _showSnack('Removed from watchlist');
      } catch (e) {
        Logger.e('Failed to remove from watchlist', error: e);
        if (mounted) {
          setState(() => _currentStatus = previousStatus);
          _showSnack('Failed to remove — please try again');
        }
      }
    } else {
      // Optimistically update the chip UI.
      setState(() => _currentStatus = newStatus);
      try {
        // Auto-detect anime so the dashboard's Anime rail picks it up
        // automatically. We do this against TMDB /details because that's the
        // only endpoint that reliably returns `original_language` + nested
        // `genres` for TV. If the network call fails we just fall back to
        // whatever the item already has.
        bool? detectedAnime;
        if (!widget.item.isAnime) {
          try {
            Logger.d("[Status] Checking if item is anime...");
            detectedAnime = await _tmdbService.isAnimeByTmdbId(
              widget.item.tmdbId,
              widget.item.mediaType,
            );
            Logger.d("[Status] Anime detection result: $detectedAnime");
          } catch (_) {
            Logger.d("[Status] Anime detection failed, continuing");
            // Anime detection is best-effort; don't let a TMDB failure
            // block the status save.
          }
        }
        // Use the poster URL from the fetched details when the item from
        // Firestore didn't have one (e.g. older items saved before posterPath
        // was stored). This ensures the dashboard cards get their images.
        final resolvedItem = _resolvePosterFromDetails(widget.item);
        Logger.d("[Status] Calling saveToWatchList...");

        // Detect partner-specific statuses (e.g. "watched-clair") and
        // route the save to the partner's document instead of the
        // current user's.
        final statusOwner = TMDBService.resolveStatusOwner(newStatus, userName);
        if (statusOwner != null) {
          Logger.d(
            "[Status] Partner-specific status detected — routing to $statusOwner",
          );
        }

        await _tmdbService.saveToWatchList(
          resolvedItem,
          newStatus,
          userName,
          isAnimeOverride: detectedAnime,
          statusOwner: statusOwner,
        );

        // For "Both" statuses (watched-both, watching-both), also update
        // the partner's document so both partners are marked. Without
        // this, "Both Watched" would only save to the current user.
        if (newStatus == 'watched-both' || newStatus == 'watching-both') {
          final partner = partnerUsername;
          if (partner != null && partner.isNotEmpty) {
            final selfStatus = newStatus == 'watched-both'
                ? 'watched-self'
                : 'watching-self';
            Logger.d(
              "[Status] Both status â€” also saving $selfStatus to partner $partner",
            );
            try {
              await _tmdbService.saveToWatchList(
                resolvedItem,
                selfStatus,
                partner,
                isAnimeOverride: detectedAnime,
              );
            } catch (e) {
              Logger.e(
                "[Status] Failed to save Both status to partner",
                error: e,
              );
              // Non-critical â€” the current user's save already succeeded.
            }
          }
        }

        // Clean up stale partner-specific status from the current user's
        // document. e.g. if Khent's doc says "watching-clair" and the user
        // just marked Clair as watched, the old "watching-clair" on Khent's
        // doc would pollute the couple merge.
        if (statusOwner != null && statusOwner != userName) {
          Logger.d(
            "[Status] Cleaning stale partner status from current user's doc",
          );
          try {
            await _tmdbService.cleanStalePartnerStatus(
              widget.item.tmdbId,
              userName,
              newStatus,
            );
          } catch (e) {
            Logger.e("[Status] Failed to clean stale status", error: e);
            // Non-critical — don't revert the main save.
          }
        }

        Logger.d("[Status] saveToWatchList completed successfully");
        if (mounted) _showSnack('Watchlist updated');
      } catch (e) {
        Logger.e('Failed to update watchlist status', error: e);
        if (mounted) {
          setState(() => _currentStatus = previousStatus);
          _showSnack('Failed to update — please try again');
        }
      }
    }
  }

  /// When the item from Firestore has an empty posterPath, pull the
  /// poster from the TMDB or AniList details that were fetched when
  /// the drawer opened. This backfills missing posters on save.
  MediaItem _resolvePosterFromDetails(MediaItem item) {
    if (item.posterPath.isNotEmpty) return item;

    final String? resolvedPoster;
    final String? resolvedBackdrop;

    if (_isAnimeSourced) {
      // AniList stores the full URL in _posterUrl / _backdropUrl.
      resolvedPoster = _details?['_posterUrl'] as String?;
      resolvedBackdrop = _details?['_backdropUrl'] as String?;
    } else {
      // TMDB poster_path is a relative path — prepend the base URL.
      final rawPoster = _details?['poster_path'] as String?;
      resolvedPoster = rawPoster != null && rawPoster.isNotEmpty
          ? 'https://image.tmdb.org/t/p/w500$rawPoster'
          : null;
      final rawBackdrop = _details?['backdrop_path'] as String?;
      resolvedBackdrop = rawBackdrop != null && rawBackdrop.isNotEmpty
          ? 'https://image.tmdb.org/t/p/w780$rawBackdrop'
          : null;
    }

    if (resolvedPoster == null && resolvedBackdrop == null) return item;

    return item.copyWith(
      posterPath: resolvedPoster ?? item.posterPath,
      backdropPath: resolvedBackdrop ?? item.backdropPath,
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: AppTypography.outfitWhite),
        backgroundColor: AppColors.deepRose,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }


  void _playMovie() {
    final id = _isAnimeSourced ? _effectiveMalId : widget.item.tmdbId;
    final malIdParam = _isAnimeSourced ? '&malId=$_effectiveMalId' : '';
    context.push(
      '/cinema/video/$id?type=movie&title=${Uri.encodeComponent(widget.item.title)}&anime=$_isAnimeSourced$malIdParam',
    );
  }

  void _playEpisode(int season, int episode, String epTitle) {
    final id = _isAnimeSourced ? _effectiveMalId : widget.item.tmdbId;
    final malIdParam = _isAnimeSourced ? '&malId=$_effectiveMalId' : '';
    final title = '${cleanTitle(widget.item.title)}: $epTitle';
    context.push(
      '/cinema/video/$id?type=tv&title=${Uri.encodeComponent(title)}&season=$season&episode=$episode&anime=$_isAnimeSourced$malIdParam',
    );
  }

  void _showSimilarItem(MediaItem item) {
    Navigator.pop(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          EpisodeDrawer(item: item, cinemaVariant: widget.cinemaVariant),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════

}

