part of 'episode_drawer.dart';

abstract class _EpisodeDrawerStateCore2 extends _EpisodeDrawerStateCore {
  Future<void> _updateStatus(String newStatus) {
    // Immediate tap feedback — haptics fire at tap time, not when the
    // queued write runs, so rapid taps never feel dead on slow network.
    HapticFeedback.selectionClick();
    // Capture auth synchronously: the queued write may run after an async
    // gap, when context.read would be unsafe.
    final auth = context.read<AuthService>();
    final userName = auth.currentUser ?? '';
    final partnerUsername = auth.partnerUsername;
    final isCoupleUser = auth.isCoupleUser;
    // Serial queue: rapid taps process in order instead of racing (the
    // original bug) or being silently dropped (the iPhone hang Khent saw
    // — taps ignored for seconds while the network was slow, then working
    // again with no feedback about the lost tap).
    final next = _statusQueue.then(
      (_) => _doUpdateStatus(
        newStatus,
        userName: userName,
        partnerUsername: partnerUsername,
        isCoupleUser: isCoupleUser,
      ),
    );
    // Keep the chain alive even if one write fails.
    _statusQueue = next.catchError((_) {});
    return next;
  }

  /// Updates [_statusNotifier] without rebuilding the drawer body.
  /// Only the chips listen to the notifier (see [_buildStatusChip]), so
  /// the hero/trailer/episodes never relay out for a status tap.
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
    // ── Guard: only couple users may set partner-specific statuses.
    // Non-couple profiles (Breyan, Octagram, guests, or any unknown user)
    // default to the generic statuses. This is defense-in-depth even when
    // the UI correctly hides the chips — it blocks direct calls / stale
    // taps from writing Khent/Clair semantics into Firestore. Removal
    // (tapping the already-selected chip) is still allowed so stale
    // partner data can be cleared.
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
        if (mounted) _showSnack('This status is only available to Khent & Clair');
        return;
      }
    }
    // Save the previous status so we can revert locally if the Firestore
    // write fails. Without this, a network error in isAnimeByTmdbId or
    // saveToWatchList would leave the chip highlighted (from the optimistic
    // notifier update) while the document in Firestore still has the old
    // status — making the change appear to "revert" when the stream fires.
    final previousStatus = _currentStatus;

    if (_currentStatus == newStatus) {
      // Tapping the already-selected chip → remove from watchlist.
      // Route to the owning doc: partner-specific statuses (e.g.
      // watching-clair) live on the partner's doc, and items opened from
      // the partner's Currently Watching row carry the partner's userName.
      // Removing from the current user instead would delete the wrong doc
      // (or nothing) and the shelf would appear to never update.
      Logger.d("[Status] Same status tapped — removing from watchlist");
      _setStatus('');
      // Immediate feedback: the chip already flipped via the notifier.
      // The old code waited for the Firestore round-trip before showing
      // anything, so a slow phone sat silent for seconds (the hang).
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
        // Fast path: the drawer often already holds the Firestore doc id
        // (items opened from a shelf). Deleting by id skips the query +
        // delete round-trips. Merged couple items (userName "a,b") keep
        // the primary's id, so only use it for single-owner matches.
        String? docId;
        if (widget.item.id.isNotEmpty &&
            widget.item.userName.trim() == ownerToRemove) {
          docId = widget.item.id;
        }
        await _tmdbService.removeFromWatchList(
          widget.item.tmdbId,
          ownerToRemove,
          docId: docId,
        );
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
      } catch (e) {
        Logger.e('Failed to remove from watchlist', error: e);
        if (mounted) {
          _setStatus(previousStatus);
          _showSnackError('Failed to remove — please try again');
        }
      }
    } else {
      // Optimistically update the chip UI + confirm now; the network
      // (anime probe + Firestore writes) lands in the background.
      _setStatus(newStatus);
      if (mounted) _showSnack('Watchlist updated');
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

        // For "Both" statuses (watched-both, watching-both), also update
        // the partner's document so both partners are marked. Without
        // this, "Both Watched" would only save to the current user.
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
      } catch (e) {
        Logger.e('Failed to update watchlist status', error: e);
        if (mounted) {
          _setStatus(previousStatus);
          _showSnackError('Failed to update — please try again');
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
        backgroundColor: AppColors.deepRose,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Error variant: replaces the optimistic confirm shown at tap time
  /// instead of queuing behind its 2s duration.
  void _showSnackError(String msg) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
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
    final posterParam = widget.item.posterPath.isNotEmpty
        ? '&poster=${Uri.encodeComponent(widget.item.posterPath)}'
        : '';
    context.push(
      '/cinema/video/$id?type=movie&title=${Uri.encodeComponent(widget.item.title)}&anime=$_isAnimeSourced$malIdParam$posterParam',
    );
  }

  void _playEpisode(int season, int episode, String epTitle) {
    final id = _isAnimeSourced ? _effectiveMalId : widget.item.tmdbId;
    final malIdParam = _isAnimeSourced ? '&malId=$_effectiveMalId' : '';
    final posterParam = widget.item.posterPath.isNotEmpty
        ? '&poster=${Uri.encodeComponent(widget.item.posterPath)}'
        : '';
    final title = '${cleanTitle(widget.item.title)}: $epTitle';
    context.push(
      '/cinema/video/$id?type=tv&title=${Uri.encodeComponent(title)}&season=$season&episode=$episode&anime=$_isAnimeSourced$malIdParam$posterParam',
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
