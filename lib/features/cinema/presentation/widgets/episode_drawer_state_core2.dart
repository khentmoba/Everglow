part of 'episode_drawer.dart';

abstract class _EpisodeDrawerStateCore2 extends _EpisodeDrawerStateCore {
  @override
  Future<void> _updateStatus(String newStatus) {
    HapticFeedback.selectionClick();
    final auth = context.read<AuthService>();
    final userName = auth.currentUser ?? '';
    final partnerUsername = auth.partnerUsername;
    final isCoupleUser = auth.isCoupleUser;
    final next = _statusQueue.then(
      (_) => _doUpdateStatus(
        newStatus,
        userName: userName,
        partnerUsername: partnerUsername,
        isCoupleUser: isCoupleUser,
      ),
    );
    _statusQueue = next.catchError((_) {});
    return next;
  }

  void _setStatus(String value) {
    if (!mounted) return;
    _statusNotifier.value = value;
  }

  Future<void> _doUpdateStatus(
    String newStatus, {
    required String userName,
    required String? partnerUsername,
    required bool isCoupleUser,
  }) async {
    if (!mounted) return;
    Logger.d(
      "[Status] _updateStatus called: newStatus=$newStatus, userName=$userName, currentItemStatus=${widget.item.status}, currentLocalStatus=$_currentStatus, tmdbId=${widget.item.tmdbId}, isAnime=${widget.item.isAnime}, mediaType=${widget.item.mediaType}, mounted=$mounted",
    );
    if (userName.isEmpty) {
      if (mounted) _showSnack('Please sign in to manage your watchlist');
      return;
    }
    if (!isCoupleUser && _currentStatus != newStatus) {
      const partnerStatuses = {
        'watching-khent',
        'watching-clair',
        'watching-both',
        'watched-khent',
        'watched-clair',
        'watched-both',
      };
      if (partnerStatuses.contains(newStatus)) {
        Logger.w(
          "[Status] Blocked partner-specific status '$newStatus' for non-couple user $userName",
        );
        if (mounted) {
          _showSnack('This status is only available to Khent & Clair');
        }
        return;
      }
    }
    final previousStatus = _currentStatus;

    if (_currentStatus == newStatus) {
      Logger.d("[Status] Same status tapped — removing from watchlist");
      _setStatus('');
      if (mounted) _showSnack('Removed from watchlist');
      try {
        String ownerToRemove = userName;
        final routedOwner = TMDBService.resolveStatusOwner(
          previousStatus,
          userName,
        );
        if (routedOwner != null) {
          ownerToRemove = routedOwner;
        } else if (previousStatus != 'watched-both' &&
            previousStatus != 'watching-both') {
          final itemOwner = widget.item.userName.trim();
          if (itemOwner == 'khentsgdz' || itemOwner == 'clairjassen') {
            ownerToRemove = itemOwner;
          }
        }
        Logger.d(
          "[Status] Removing tmdbId=${widget.item.tmdbId} from owner=$ownerToRemove (previous=$previousStatus, viewer=$userName)",
        );
        await _tmdbService.removeFromWatchList(widget.item, ownerToRemove);
        if (previousStatus == 'watched-both' ||
            previousStatus == 'watching-both') {
          if (partnerUsername != null && partnerUsername.isNotEmpty) {
            Logger.d(
              "[Status] Both status — also removing from partner $partnerUsername",
            );
            try {
              await _tmdbService.removeFromWatchList(
                widget.item,
                partnerUsername,
              );
            } catch (e) {
              Logger.e("[Status] Failed to remove from partner", error: e);
            }
          }
        }
        Logger.d("[Status] Remove succeeded");
      } catch (e) {
        Logger.e('Failed to remove from watchlist', error: e);
        if (mounted) {
          _setStatus(previousStatus);
          _showSnackError('Failed to remove — please try again');
        }
      }
    } else {
      _setStatus(newStatus);
      if (mounted) _showSnack('Watchlist updated');
      try {
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
          }
        }
        final resolvedItem = _resolvePosterFromDetails(widget.item);
        Logger.d("[Status] Calling saveToWatchList...");

        final statusOwner = TMDBService.resolveStatusOwner(newStatus, userName);
        if (statusOwner != null) {
          Logger.d(
            "[Status] Partner-specific status detected — routing to $statusOwner",
          );
        }

        final isBoth =
            newStatus == 'watched-both' || newStatus == 'watching-both';
        await _tmdbService.saveToWatchList(
          resolvedItem,
          newStatus,
          userName,
          isAnimeOverride: detectedAnime,
          statusOwner: statusOwner,
          skipPartnerFallback: isBoth,
        );

        if (isBoth) {
          final partner = partnerUsername;
          if (partner != null && partner.isNotEmpty) {
            Logger.d(
              "[Status] Both status — also saving $newStatus to partner $partner",
            );
            try {
              await _tmdbService.saveToWatchList(
                resolvedItem,
                newStatus,
                partner,
                isAnimeOverride: detectedAnime,
                skipPartnerFallback: true,
              );
            } catch (e) {
              Logger.e(
                "[Status] Failed to save Both status to partner",
                error: e,
              );
            }
          }
        }

        if (statusOwner != null && statusOwner != userName) {
          Logger.d(
            "[Status] Cleaning stale partner status from current user's doc",
          );
          try {
            await _tmdbService.cleanStalePartnerStatus(
              widget.item,
              userName,
              newStatus,
            );
          } catch (e) {
            Logger.e("[Status] Failed to clean stale status", error: e);
          }
        }

        Logger.d("[Status] saveToWatchList completed successfully");
      } catch (e) {
        Logger.e('Failed to update watchlist status', error: e);
        if (mounted) {
          _setStatus(previousStatus);
          _showSnackError('Failed to update — please try again');
        }
      }
    }
  }

  MediaItem _resolvePosterFromDetails(MediaItem item) {
    if (item.posterPath.isNotEmpty) return item;

    final String? resolvedPoster;
    final String? resolvedBackdrop;

    if (_isAnimeSourced) {
      resolvedPoster = _details?['_posterUrl'] as String?;
      resolvedBackdrop = _details?['_backdropUrl'] as String?;
    } else {
      final rawPoster = _details?['poster_path'] as String?;
      resolvedPoster = rawPoster != null && rawPoster.isNotEmpty
          ? TmdbImages.posterFor(rawPoster)
          : null;
      final rawBackdrop = _details?['backdrop_path'] as String?;
      resolvedBackdrop = rawBackdrop != null && rawBackdrop.isNotEmpty
          ? TmdbImages.backdropFor(rawBackdrop)
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
        backgroundColor: widget.cinemaVariant
            ? NetflixColors.surfaceElevated
            : AppColors.deepRose,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showSnackError(String msg) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(msg, style: AppTypography.outfitWhite),
        backgroundColor: widget.cinemaVariant
            ? NetflixColors.surfaceElevated
            : AppColors.deepRose,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _playMovie() {
    final id = _isAnimeSourced ? _effectiveMalId : widget.item.tmdbId;
    final malIdParam = _isAnimeSourced ? '&malId=$_effectiveMalId' : '';
    final posterParam = widget.item.posterPath.isNotEmpty
        ? '&poster=${Uri.encodeComponent(widget.item.posterPath)}'
        : '';
    context.push(
      '/cinema/video/$id?type=movie&title=${Uri.encodeComponent(widget.item.title)}&anime=$_isAnimeSourced$malIdParam$posterParam',
    );
  }

  void _playEpisode(int season, int episode, String _) {
    final id = _isAnimeSourced ? _effectiveMalId : widget.item.tmdbId;
    final malIdParam = _isAnimeSourced ? '&malId=$_effectiveMalId' : '';
    final posterParam = widget.item.posterPath.isNotEmpty
        ? '&poster=${Uri.encodeComponent(widget.item.posterPath)}'
        : '';
    final title = cleanTitle(widget.item.title);
    final watchedParam = !_isAnimeSourced && widget.item.isWatched
        ? '&watched=true'
        : '';
    final duration = widget.item.durationSeconds ?? 0;
    final completedParam =
        !_isAnimeSourced &&
            season == widget.item.currentSeason &&
            episode == widget.item.currentEpisode &&
            duration > 0 &&
            (widget.item.currentTimestamp ?? 0) / duration >= 0.95
        ? '&completed=true'
        : '';
    context.push(
      '/cinema/video/$id?type=tv&title=${Uri.encodeComponent(title)}&season=$season&episode=$episode&anime=$_isAnimeSourced$watchedParam$completedParam$malIdParam$posterParam',
    );
  }

  void _showSimilarItem(MediaItem item) {
    Navigator.pop(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => EpisodeDrawer(
        item: item,
        cinemaVariant: widget.cinemaVariant,
        topTenRank: topTenRankFor(widget.topTenItems ?? const [], item),
      ),
    );
  }
}
