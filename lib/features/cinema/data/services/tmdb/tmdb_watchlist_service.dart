import 'dart:async';
import '../../../../../core/agent/agent_mode.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../../core/utils/connectivity_aware.dart';
import '../../../../../core/utils/firestore_stream_utils.dart';
import '../../../../../core/utils/logger.dart';
import '../../models/media_item.dart';
import 'tmdb_base.dart';
import 'tmdb_cache_service.dart';

/// Firestore-backed watchlist CRUD, couple-merge streams, currently-watching
/// streams, progress tracking, and one-time migration helpers.
/// Agent sessions return empty lists and skip persistence; drawer selections
/// remain local to the widget and never touch live or cached couple data.
class TMDBWatchlistService with TMDBBase, ConnectivityAware {
  final TMDBCacheService _cacheService;

  TMDBWatchlistService(this._cacheService);

  // Bounds every live watch-list query below. A couple list stays far
  // under this in practice; the cap keeps Firestore reads finite.
  static const int streamLimit = 500;

  // Bound for dashboard preview rails: each shelf sub-row renders up to
  // 12 cards and headers only show counts, so a 500-doc realtime stream
  // per sub-row is heavy on every dashboard visit. Full history stays
  // on the un-capped streams for the cinema/anime screens.
  static const int previewLimit = 24;

  static String _mediaType(String value) =>
      value.trim().toLowerCase() == 'tv' ? 'tv' : 'movie';

  static int _catalogId(MediaItem item) =>
      item.tmdbId > 0 ? item.tmdbId : (item.anilistId ?? 0);

  static bool _matchesCatalog(
    Map<String, dynamic> data, {
    required int id,
    required String source,
    required String mediaType,
  }) =>
      data['tmdbId'] == id &&
      (data['source'] ?? 'tmdb') == source &&
      _mediaType(data['mediaType'] as String? ?? 'movie') ==
          _mediaType(mediaType);

  static QueryDocumentSnapshot<Map<String, dynamic>>? _findCatalogDoc(
    QuerySnapshot<Map<String, dynamic>> snapshot, {
    required int id,
    required String source,
    required String mediaType,
  }) {
    for (final doc in snapshot.docs) {
      if (_matchesCatalog(
        doc.data(),
        id: id,
        source: source,
        mediaType: mediaType,
      )) {
        return doc;
      }
    }
    return null;
  }

  static QueryDocumentSnapshot<Map<String, dynamic>>? _findAniListDoc(
    QuerySnapshot<Map<String, dynamic>> snapshot, {
    required int anilistId,
    required String source,
    required String mediaType,
  }) {
    for (final doc in snapshot.docs) {
      final data = doc.data();
      // Missing source normally means TMDB; an exact AniList link safely
      // identifies older anime records that predate the source field.
      if (data['anilistId'] == anilistId &&
          data['isAnime'] == true &&
          _mediaType(data['mediaType'] as String? ?? 'movie') ==
              _mediaType(mediaType) &&
          ((data['source'] ?? 'tmdb') == source ||
              (!data.containsKey('source') && source != 'tmdb'))) {
        return doc;
      }
    }
    return null;
  }

  /// Lightweight one-shot fetch for dashboard previews. Reads [limit]
  /// docs once instead of holding a realtime stream each (Cinema + Anime
  /// + Currently Watching previously opened ~1500 realtime docs per
  /// dashboard mount).
  Future<List<MediaItem>> getPreviewItems(
    String userName, {
    int limit = 30,
    bool? isAnime,
  }) async {
    if (AgentMode.isActive.value) return const [];
    if (userName.isEmpty) return const [];
    Query<Map<String, dynamic>> query = firestore
        .collection('watch_list')
        .where('userName', isEqualTo: userName);
    if (isAnime != null) {
      query = query.where('isAnime', isEqualTo: isAnime);
    }
    final snapshot = await withGetTimeout(
      query.orderBy('addedAt', descending: true).limit(limit).get(),
      label: 'watchlist preview',
    );
    final items =
        snapshot.docs
            .map((doc) => MediaItem.fromFirestore(doc.data(), doc.id))
            .toList()
          ..sort((a, b) => b.addedAt.compareTo(a.addedAt));
    return items;
  }

  // ─── CRUD ──────────────────────────────────────────────────────────────

  Future<void> saveToWatchList(
    MediaItem item,
    String status,
    String userName, {
    bool? isAnimeOverride,
    String? statusOwner,
    bool skipPartnerFallback = false,
  }) async {
    if (AgentMode.isActive.value) return;
    if (userName.isEmpty) {
      Logger.w("Error saving to watch list: userName is empty");
      return;
    }
    // ── Guard: non-couple users (Breyan, Octagram, guests) may only use
    // generic statuses. Partner-specific statuses would store Khent/Clair
    // semantics under an isolated account and leak via merges.
    const coupleStatuses = {
      'watching-khent',
      'watching-clair',
      'watching-both',
      'watched-khent',
      'watched-clair',
      'watched-both',
    };
    final isCoupleOwner = userName == 'khentsgdz' || userName == 'clairjassen';
    if (!isCoupleOwner && coupleStatuses.contains(status)) {
      Logger.w(
        "[WatchList] Blocked partner status '$status' for non-couple user $userName",
      );
      return;
    }
    if (statusOwner != null) {
      final isCoupleStatusOwner =
          statusOwner == 'khentsgdz' || statusOwner == 'clairjassen';
      if (!isCoupleOwner || !isCoupleStatusOwner) {
        Logger.w(
          "[WatchList] Blocked statusOwner routing '$statusOwner' for user $userName / status $status",
        );
        return;
      }
    }
    try {
      final collection = firestore.collection('watch_list');

      // Determine whose document to update. When a couple user taps a
      // partner-specific chip (e.g. "Clair Watched"), the status should
      // go on the *partner's* document, not the current user's.
      // [statusOwner] is set by the drawer when it detects a partner-
      // specific status.
      final effectiveOwner = statusOwner ?? userName;

      // Map partner-specific statuses to "self" variants on the owner's
      // document. "watched-clair" on Clair's doc → "watched-self", etc.
      final effectiveStatus = _toSelfStatus(status);

      final catalogId = _catalogId(item);
      // Filter the small same-numeric-ID result in Dart; adding source and
      // mediaType to the Firestore query would require new composite indexes.
      Logger.d(
        "[WatchList] Querying catalogId=$catalogId, owner=$effectiveOwner, status=$effectiveStatus, title=${item.title}",
      );
      final existing = await withGetTimeout(
        collection
            .where('tmdbId', isEqualTo: catalogId)
            .where('userName', isEqualTo: effectiveOwner)
            .get(),
        label: 'watchlist save lookup',
      );
      var existingItem = _findCatalogDoc(
        existing,
        id: catalogId,
        source: item.source,
        mediaType: item.mediaType,
      );
      if (existingItem == null &&
          item.isAnime &&
          item.source != 'tmdb' &&
          (item.anilistId ?? 0) > 0) {
        final byAniListId = await withGetTimeout(
          collection
              .where('anilistId', isEqualTo: item.anilistId)
              .where('userName', isEqualTo: effectiveOwner)
              .where('isAnime', isEqualTo: true)
              .get(),
          label: 'watchlist save AniList lookup',
        );
        existingItem = _findAniListDoc(
          byAniListId,
          anilistId: item.anilistId!,
          source: item.source,
          mediaType: item.mediaType,
        );
      }
      Logger.d(
        "[WatchList] Query returned ${existing.docs.length} docs for owner=$effectiveOwner",
      );

      // NOTE: no partner fallback. Every dashboard/cinema shelf uses
      // per-user streams (`where userName == X`), so each user's writes
      // must stay on their own document. Hijacking the partner's doc
      // would overwrite the partner's status (e.g. resetting their
      // watched entry to to-watch) and leave the writer's own shelf
      // permanently empty - the 'movies gone from Currently Watching /
      // Watched' bug. When the owner has no doc we always create one
      // below. [skipPartnerFallback] is kept for API compatibility.
      assert(skipPartnerFallback || !skipPartnerFallback);

      // Determine the anime flag. If the caller passed an explicit override
      // (e.g. the episode drawer detected anime via /details), trust it.
      // Otherwise fall back to whatever was already on the item.
      final isAnime = isAnimeOverride ?? item.isAnime;

      if (existingItem != null) {
        Logger.d(
          "[WatchList] Updating existing doc ${existingItem.id} with status=$effectiveStatus, owner=$effectiveOwner",
        );
        // Update status if exists — also refresh metadata fields so the
        // dashboard cards always have the latest poster, title, etc.
        // (Items saved before posterPath was stored get their poster
        //  on the next status change rather than staying blank forever.)
        //
        // Only overwrite posterPath when the incoming item actually has
        // one — prevents an empty posterPath (e.g. from a stale Jikan
        // search result) from clobbering an already-saved poster.
        final updateData = <String, dynamic>{
          'status': effectiveStatus,
          'isAnime': isAnime,
          'addedAt': Timestamp.now(),
          'backdropPath': item.backdropPath,
          'title': item.title,
          'year': item.year,
          'mediaType': item.mediaType,
          'source': item.source,
        };
        if (item.posterPath.isNotEmpty) {
          updateData['posterPath'] = item.posterPath;
        }
        // Rewatch: tapping Watching on a completed season (EP 12/12)
        // restarts it at EP 1 — without the reset the completion rule
        // above would keep it in Finished and the chip would lie.
        if (effectiveStatus.startsWith('watching') && item.isSeriesCompleted) {
          updateData['currentEpisode'] = 1;
          updateData['currentTimestamp'] = null;
          updateData['durationSeconds'] = null;
          updateData['progressUpdatedAt'] = Timestamp.now();
        }
        await collection.doc(existingItem.id).update(updateData);
        Logger.d("[WatchList] Update succeeded for doc ${existingItem.id}");
      } else {
        // Create new entry scoped to the effective owner
        Logger.d(
          "[WatchList] No existing doc found — creating new entry for owner=$effectiveOwner",
        );
        await collection.add(
          item
              .copyWith(
                tmdbId: catalogId,
                status: effectiveStatus,
                isAnime: isAnime,
                userName: effectiveOwner,
                addedAt: DateTime.now(),
              )
              .toFirestore(),
        );
        Logger.d("[WatchList] New entry created successfully");
      }
      Logger.i(
        "Saved to watch list successfully: ${item.title} ($effectiveOwner, status=$effectiveStatus)",
      );
    } catch (e, st) {
      Logger.e("Error saving to watch list", error: e);
      Logger.d("[WatchList] Stack trace: $st");
      rethrow; // Let the caller know the save failed so it can revert UI state.
    }
  }

  /// Maps partner-specific statuses to the "self" variant that should be
  /// stored on the owner's document.
  ///   "watched-clair"  → "watched-self"
  ///   "watched-khent"  → "watched-self"
  ///   "watching-clair" → "watching-self"
  ///   "watching-khent" → "watching-self"
  ///   "watched-both" / "watching-both" are preserved as-is so a
  ///   single doc can represent "Both Watched" without needing a merge.
  ///   anything else    → as-is
  static String _toSelfStatus(String status) {
    switch (status) {
      case 'watched-clair':
      case 'watched-khent':
        return 'watched-self';
      case 'watching-clair':
      case 'watching-khent':
        return 'watching-self';
      default:
        return status;
    }
  }

  /// Returns the Firestore userName of the partner that a partner-specific
  /// status refers to, or null if the status isn't partner-specific.
  ///   "watched-clair" / "watching-clair" → "clairjassen"
  ///   "watched-khent"  / "watching-khent" → "khentsgdz"
  ///   "watched-both" / "watching-both" → null (ambiguous — both)
  static String? resolveStatusOwner(String status, String currentUser) {
    switch (status) {
      case 'watched-clair':
      case 'watching-clair':
        return 'clairjassen';
      case 'watched-khent':
      case 'watching-khent':
        return 'khentsgdz';
      default:
        return null; // Use currentUser (the standard path)
    }
  }

  /// The caller's saved progress for a catalog identity, or null when there
  /// is none (or the read failed). Never throws: resuming is a comfort, not
  /// a reason to block playback.
  Future<MediaItem?> getSavedProgress(
    int catalogId,
    String userName, {
    required String source,
    required String mediaType,
    int? anilistId,
  }) async {
    if (AgentMode.isActive.value) return null;
    if (userName.isEmpty || (catalogId <= 0 && (anilistId ?? 0) <= 0)) {
      return null;
    }
    try {
      // Exact AniList IDs can resume a saved MAL entry whose MAL ID differs.
      if (anilistId != null && anilistId > 0) {
        final anime = await withGetTimeout(
          firestore
              .collection('watch_list')
              .where('anilistId', isEqualTo: anilistId)
              .where('userName', isEqualTo: userName)
              .where('isAnime', isEqualTo: true)
              .get(),
          label: 'saved anime progress lookup',
        );
        final doc = _findAniListDoc(
          anime,
          anilistId: anilistId,
          source: source,
          mediaType: mediaType,
        );
        if (doc != null) return MediaItem.fromFirestore(doc.data(), doc.id);
      }
      if (catalogId <= 0) return null;
      final snap = await withGetTimeout(
        firestore
            .collection('watch_list')
            .where('tmdbId', isEqualTo: catalogId)
            .where('userName', isEqualTo: userName)
            .get(),
        label: 'saved watch progress lookup',
      );
      final doc = _findCatalogDoc(
        snap,
        id: catalogId,
        source: source,
        mediaType: mediaType,
      );
      if (doc == null) return null;
      final savedAniListId = doc.data()['anilistId'];
      if ((anilistId ?? 0) > 0 &&
          savedAniListId != null &&
          savedAniListId != anilistId) {
        return null;
      }
      return MediaItem.fromFirestore(doc.data(), doc.id);
    } catch (e) {
      Logger.e('Error reading saved watch progress', error: e);
      return null;
    }
  }

  /// Update watch progress fields for a specific watch_list item.
  /// Creates the entry first if it doesn't exist (for first-time watch).
  Future<void> updateProgress(
    MediaItem item,
    String userName, {
    int? season,
    int? episode,
    int? timestamp,
    int? durationSeconds,
    String? status,
  }) async {
    if (AgentMode.isActive.value) return;
    if (userName.isEmpty) return;
    try {
      final collection = firestore.collection('watch_list');
      final effectiveTmdbId = item.tmdbId > 0
          ? item.tmdbId
          : (item.anilistId ?? 0);
      if (effectiveTmdbId <= 0) return;

      QueryDocumentSnapshot<Map<String, dynamic>>? document;
      if (item.isAnime && item.source != 'tmdb' && (item.anilistId ?? 0) > 0) {
        final anime = await withGetTimeout(
          collection
              .where('anilistId', isEqualTo: item.anilistId)
              .where('userName', isEqualTo: userName)
              .where('isAnime', isEqualTo: true)
              .get(),
          label: 'watch progress AniList lookup',
        );
        document = _findAniListDoc(
          anime,
          anilistId: item.anilistId!,
          source: item.source,
          mediaType: item.mediaType,
        );
      }
      if (document == null && item.tmdbId > 0) {
        final byCatalogId = await withGetTimeout(
          collection
              .where('tmdbId', isEqualTo: item.tmdbId)
              .where('userName', isEqualTo: userName)
              .get(),
          label: 'watch progress lookup',
        );
        document = _findCatalogDoc(
          byCatalogId,
          id: item.tmdbId,
          source: item.source,
          mediaType: item.mediaType,
        );
      }
      final savedAniListId = document?.data()['anilistId'];
      final conflictingAnime =
          item.isAnime &&
          item.anilistId != null &&
          savedAniListId != null &&
          savedAniListId != item.anilistId;

      // NOTE: no partner fallback (see saveToWatchList). Progress and
      // removals only ever touch the caller's own document; when none
      // exists we create one (progress) or do nothing (remove/
      // heartbeat) instead of hijacking the partner's doc.

      final now = Timestamp.now();
      final data = <String, dynamic>{
        'currentSeason': season,
        'currentEpisode': episode,
        'currentTimestamp': timestamp,
        'durationSeconds': durationSeconds,
        'progressUpdatedAt': now,
      };
      // Normalize partner-specific values (watching-khent/clair) to the
      // self-variant so per-user shelves and the drawer stay consistent
      // with saveToWatchList.
      var effectiveStatus = status == null ? null : _toSelfStatus(status);
      // MAL-style auto-complete: saving the finale flips watching to
      // watched so finished seasons land in Finished/Completed. Explicit
      // to-watch (progress clear) and already-watched statuses pass
      // through untouched; cinema callers carry no episodeCount so they
      // never trigger this.
      final hitsFinale = MediaItem.isCompletedProgress(
        episode: episode,
        totalEpisodes: item.episodeCount,
        isMovie: item.isMovie,
      );
      if (hitsFinale &&
          (effectiveStatus == null || effectiveStatus.startsWith('watching'))) {
        effectiveStatus = 'watched-self';
      }
      if (effectiveStatus != null) data['status'] = effectiveStatus;
      // Keep the known total on the doc so old entries saved without one
      // still auto-complete once the catalog reports the count.
      if (item.episodeCount != null) {
        data['episodeCount'] = item.episodeCount;
      }

      if (document != null && !conflictingAnime) {
        final existingData = document.data();
        final existingPoster = existingData['posterPath'] as String?;
        if (item.posterPath.isNotEmpty &&
            (existingPoster == null || existingPoster.isEmpty)) {
          data['posterPath'] = item.posterPath;
        }
        final existingTitle = existingData['title'] as String?;
        if (item.title.isNotEmpty &&
            (existingTitle == null || existingTitle.isEmpty)) {
          data['title'] = item.title;
        }
        await collection.doc(document.id).update(data);
      } else {
        await collection.add(
          item
              .copyWith(
                tmdbId: effectiveTmdbId,
                status: effectiveStatus ?? 'watching-self',
                userName: userName,
                isAnime: item.isAnime,
                addedAt: DateTime.now(),
                currentSeason: season,
                currentEpisode: episode,
                currentTimestamp: timestamp,
                durationSeconds: durationSeconds,
                progressUpdatedAt: DateTime.now(),
              )
              .toFirestore(),
        );
      }
    } catch (e) {
      Logger.e('Error updating watch progress', error: e);
    }
  }

  Future<void> removeFromWatchList(MediaItem item, String userName) async {
    if (AgentMode.isActive.value) return;
    if (userName.isEmpty) return;
    try {
      final collection = firestore.collection('watch_list');
      final catalogId = item.tmdbId > 0 ? item.tmdbId : (item.anilistId ?? 0);
      final existing = await withGetTimeout(
        collection
            .where('tmdbId', isEqualTo: catalogId)
            .where('userName', isEqualTo: userName)
            .get(),
        label: 'watchlist remove lookup',
      );
      final document = _findCatalogDoc(
        existing,
        id: catalogId,
        source: item.source,
        mediaType: item.mediaType,
      );

      // NOTE: no partner fallback (see saveToWatchList). Progress and
      // removals only ever touch the caller's own document; when none
      // exists we create one (progress) or do nothing (remove/
      // heartbeat) instead of hijacking the partner's doc.

      if (document != null) {
        await collection.doc(document.id).delete();
        Logger.i("Removed from watch list: $catalogId ($userName)");
      }
    } catch (e) {
      Logger.e("Error removing from watch list", error: e);
      rethrow; // Let the caller know the removal failed so it can revert UI state.
    }
  }

  /// Removes a title from Continue Watching without dropping it from My List.
  ///
  /// Mirrors Netflix's "Remove From Row": the item keeps its place in the
  /// library under To Watch, but its playback progress is cleared so it no
  /// longer shows up in the watching shelves. Only ever touches the
  /// caller's own document (see saveToWatchList). Does nothing when the
  /// caller has no document for this catalog identity.
  Future<void> clearWatchProgress(MediaItem item, String userName) async {
    if (AgentMode.isActive.value) return;
    if (userName.isEmpty) return;
    try {
      final collection = firestore.collection('watch_list');
      final catalogId = item.tmdbId > 0 ? item.tmdbId : (item.anilistId ?? 0);
      final existing = await withGetTimeout(
        collection
            .where('tmdbId', isEqualTo: catalogId)
            .where('userName', isEqualTo: userName)
            .get(),
        label: 'watch progress clear lookup',
      );
      final document = _findCatalogDoc(
        existing,
        id: catalogId,
        source: item.source,
        mediaType: item.mediaType,
      );
      if (document == null) return;
      await collection.doc(document.id).update({
        'status': 'to-watch',
        'currentSeason': null,
        'currentEpisode': null,
        'currentTimestamp': null,
        'durationSeconds': null,
        'progressUpdatedAt': Timestamp.now(),
      });
    } catch (e) {
      Logger.e('Error clearing watch progress', error: e);
      rethrow;
    }
  }

  /// Undo only a still-cleared entry; never overwrite newer device progress.
  Future<bool> restoreWatchProgress(MediaItem item, String userName) async {
    if (AgentMode.isActive.value) return false;
    if (userName.isEmpty) return false;
    try {
      final catalogId = _catalogId(item);
      final existing = await withGetTimeout(
        firestore
            .collection('watch_list')
            .where('tmdbId', isEqualTo: catalogId)
            .where('userName', isEqualTo: userName)
            .get(),
        label: 'watch progress undo lookup',
      );
      final document = _findCatalogDoc(
        existing,
        id: catalogId,
        source: item.source,
        mediaType: item.mediaType,
      );
      if (document == null) return false;
      final ref = document.reference;
      return await firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(ref);
        final data = snapshot.data();
        if (data == null ||
            data['userName'] != userName ||
            !_matchesCatalog(
              data,
              id: catalogId,
              source: item.source,
              mediaType: item.mediaType,
            ) ||
            data['status'] != 'to-watch' ||
            data['currentTimestamp'] != null ||
            data['currentSeason'] != null ||
            data['currentEpisode'] != null) {
          return false;
        }
        transaction.update(ref, {
          'status': item.status,
          'currentSeason': item.currentSeason,
          'currentEpisode': item.currentEpisode,
          'currentTimestamp': item.currentTimestamp,
          'durationSeconds': item.durationSeconds,
          'progressUpdatedAt': Timestamp.now(),
        });
        return true;
      });
    } catch (e, st) {
      Logger.e(
        'Cinema: could not undo progress removal',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  /// Adds or removes a lightweight "My List" entry from hover previews.
  Future<bool> setListMembership(
    MediaItem item,
    String userName, {
    required bool add,
  }) async {
    if (add) {
      await saveToWatchList(item, 'to-watch', userName);
      return true;
    }
    await removeFromWatchList(item, userName);
    return false;
  }

  /// Persists a Netflix-style thumbs-up / thumbs-down rating.
  Future<void> setUserRating(
    MediaItem item,
    String userName, {
    double? rating,
  }) async {
    if (AgentMode.isActive.value) return;
    if (userName.isEmpty) return;
    try {
      final collection = firestore.collection('watch_list');
      final catalogId = _catalogId(item);
      final existing = await withGetTimeout(
        collection
            .where('tmdbId', isEqualTo: catalogId)
            .where('userName', isEqualTo: userName)
            .get(),
        label: 'watchlist rating lookup',
      );
      final document = _findCatalogDoc(
        existing,
        id: catalogId,
        source: item.source,
        mediaType: item.mediaType,
      );
      if (document == null) {
        if (rating == null) return;
        await collection.add(
          item
              .copyWith(
                tmdbId: catalogId,
                status: 'to-watch',
                userName: userName,
                userRating: rating,
                ratedAt: DateTime.now(),
              )
              .toFirestore(),
        );
        return;
      }
      await collection.doc(document.id).update({
        'userRating': rating,
        'ratedAt': rating == null ? null : Timestamp.now(),
      });
    } catch (e) {
      Logger.e('Error updating user rating', error: e);
    }
  }

  /// Toggles the "Remind me" bell for an unreleased title. Creates a
  /// lightweight To Watch entry when the caller has no document yet, so
  /// the bell survives drawer re-opens and shows up in the Library.
  Future<void> setRemindMe(
    MediaItem item,
    String userName, {
    required bool value,
  }) async {
    if (AgentMode.isActive.value) return;
    if (userName.isEmpty) return;
    try {
      final collection = firestore.collection('watch_list');
      final catalogId = item.tmdbId > 0 ? item.tmdbId : (item.anilistId ?? 0);
      final existing = await withGetTimeout(
        collection
            .where('tmdbId', isEqualTo: catalogId)
            .where('userName', isEqualTo: userName)
            .get(),
        label: 'watchlist remind-me lookup',
      );
      final document = _findCatalogDoc(
        existing,
        id: catalogId,
        source: item.source,
        mediaType: item.mediaType,
      );
      if (document == null) {
        if (!value) return;
        await collection.add(
          item
              .copyWith(
                tmdbId: catalogId,
                status: 'to-watch',
                userName: userName,
                remindMe: true,
              )
              .toFirestore(),
        );
        return;
      }
      await collection.doc(document.id).update({'remindMe': value});
    } catch (e) {
      Logger.e('Error updating reminder', error: e);
      rethrow;
    }
  }

  /// One-shot read of the "Remind me" bell for the drawer's initial state.
  Future<bool> isReminderSet(MediaItem item, String userName) async {
    if (AgentMode.isActive.value) return false;
    if (userName.isEmpty) return false;
    try {
      final catalogId = item.tmdbId > 0 ? item.tmdbId : (item.anilistId ?? 0);
      final existing = await withGetTimeout(
        firestore
            .collection('watch_list')
            .where('tmdbId', isEqualTo: catalogId)
            .where('userName', isEqualTo: userName)
            .get(),
        label: 'watchlist reminder check',
      );
      final document = _findCatalogDoc(
        existing,
        id: catalogId,
        source: item.source,
        mediaType: item.mediaType,
      );
      return document?.data()['remindMe'] == true;
    } catch (e) {
      Logger.e('Error reading reminder', error: e);
      return false;
    }
  }

  // ─── Direct Firestore streams (reverted from shared broadcast) ──
  // The previous shared _rawCache used asBroadcastStream without replay,
  // which caused late subscribers (e.g. Currently Watching shelf mounting
  // after the header) to miss the initial snapshot and stay empty until
  // the next Firestore change. It also held onto a single Firestore Watch
  // that could enter a permission-denied error state before the users/{uid}
  // doc was created. Direct streams are simpler and correct — the Web
  // SDK already shares the underlying Watch target.

  // ─── Streams ───────────────────────────────────────────────────────────

  /// Stream of watch list items for a specific user (Firestore-based).
  /// We filter+sort in Dart to avoid needing a composite index in Firestore.
  Stream<List<MediaItem>> getWatchListStream(String userName, {int? limit}) {
    if (AgentMode.isActive.value) return Stream.value(const <MediaItem>[]);
    if (userName.isEmpty) return Stream.value(const []);
    return firestore
        .collection('watch_list')
        .where('userName', isEqualTo: userName)
        .limit(limit ?? streamLimit)
        .snapshots()
        .map((snapshot) {
          final items =
              snapshot.docs
                  .map((doc) => MediaItem.fromFirestore(doc.data(), doc.id))
                  .toList()
                ..sort((a, b) => b.addedAt.compareTo(a.addedAt));
          // Side effect: Cache the list locally per user (fire-and-forget).
          unawaited(_cacheService.cacheWatchList(items, userName));
          return items;
        });
  }

  /// Stream of the combined watch list for the couple
  /// (khentsgdz + clairjassen), deduplicated by source, media type, and ID.
  ///
  /// On the merged `MediaItem`:
  ///   - `userName` is a comma-separated list of partners who have the title
  ///     (e.g. "khentsgdz", "clairjassen", or "khentsgdz,clairjassen").
  ///   - `status` is derived from both partners' statuses so the existing
  ///     `isWatched` / `watchedDisplay` helpers keep working.
  ///
  /// The dashboard preview and the wishlist/watched tabs in the cinema
  /// screen use this for the couple so both partners see the same combined
  /// catalog with khent/clair/both attribution on each row.
  Stream<List<MediaItem>> getCoupleWatchListStream({
    String userA = 'khentsgdz',
    String userB = 'clairjassen',
  }) {
    if (AgentMode.isActive.value) return Stream.value(const <MediaItem>[]);
    final controller = StreamController<List<MediaItem>>.broadcast();
    List<MediaItem> itemsA = const [];
    List<MediaItem> itemsB = const [];
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? subA;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? subB;

    void emit() {
      controller.add(_mergeCoupleItems(itemsA, itemsB));
    }

    controller.onListen = () {
      subA = firestore
          .collection('watch_list')
          .where('userName', isEqualTo: userA)
          .limit(streamLimit)
          .snapshots()
          .listen((snapshot) {
            itemsA = snapshot.docs
                .map((doc) => MediaItem.fromFirestore(doc.data(), doc.id))
                .toList();
            emit();
          });
      subB = firestore
          .collection('watch_list')
          .where('userName', isEqualTo: userB)
          .limit(streamLimit)
          .snapshots()
          .listen((snapshot) {
            itemsB = snapshot.docs
                .map((doc) => MediaItem.fromFirestore(doc.data(), doc.id))
                .toList();
            emit();
          });
    };

    controller.onCancel = () async {
      await subA?.cancel();
      await subB?.cancel();
      await controller.close();
    };

    return controller.stream;
  }

  /// Stream of anime-only items for a single user. Same source collection
  /// (`watch_list`) as the regular stream — we filter by `isAnime == true`
  /// in Dart so the dashboard's Anime rail and the AnimeScreen only show
  /// Japanese animation, no matter where the title was added.
  Stream<List<MediaItem>> getAnimeWatchListStream(
    String userName, {
    int? limit,
  }) {
    if (AgentMode.isActive.value) return Stream.value(const <MediaItem>[]);
    if (userName.isEmpty) return Stream.value(const []);
    return firestore
        .collection('watch_list')
        .where('userName', isEqualTo: userName)
        .limit(limit ?? streamLimit)
        .snapshots()
        .map((snapshot) {
          final items =
              snapshot.docs
                  .map((doc) => MediaItem.fromFirestore(doc.data(), doc.id))
                  .where((i) => i.isAnime)
                  .toList()
                ..sort((a, b) => b.addedAt.compareTo(a.addedAt));
          return items;
        });
  }

  /// Couple-scoped stream of the anime rail. Identical shape to
  /// [getCoupleWatchListStream] but the merge keeps only items where at
  /// least one partner has `isAnime == true`. The merged item's `isAnime`
  /// is the OR of the two partner entries, so partner-aware attribution
  /// keeps working.
  Stream<List<MediaItem>> getCoupleAnimeStream({
    String userA = 'khentsgdz',
    String userB = 'clairjassen',
  }) {
    if (AgentMode.isActive.value) return Stream.value(const <MediaItem>[]);
    final controller = StreamController<List<MediaItem>>.broadcast();
    List<MediaItem> itemsA = const [];
    List<MediaItem> itemsB = const [];
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? subA;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? subB;

    void emit() {
      final merged = _mergeCoupleItems(itemsA, itemsB);
      controller.add(merged.where((i) => i.isAnime).toList());
    }

    controller.onListen = () {
      subA = firestore
          .collection('watch_list')
          .where('userName', isEqualTo: userA)
          .limit(streamLimit)
          .snapshots()
          .listen((snapshot) {
            itemsA = snapshot.docs
                .map((doc) => MediaItem.fromFirestore(doc.data(), doc.id))
                .toList();
            emit();
          });
      subB = firestore
          .collection('watch_list')
          .where('userName', isEqualTo: userB)
          .limit(streamLimit)
          .snapshots()
          .listen((snapshot) {
            itemsB = snapshot.docs
                .map((doc) => MediaItem.fromFirestore(doc.data(), doc.id))
                .toList();
            emit();
          });
    };

    controller.onCancel = () async {
      await subA?.cancel();
      await subB?.cancel();
      await controller.close();
    };

    return controller.stream;
  }

  /// Stream of currently watching items for a single user.
  Stream<List<MediaItem>> getCurrentlyWatchingStream(
    String userName, {
    int? limit,
  }) {
    if (AgentMode.isActive.value) return Stream.value(const <MediaItem>[]);
    if (userName.isEmpty) return Stream.value(const []);
    return firestore
        .collection('watch_list')
        .where('userName', isEqualTo: userName)
        .limit(limit ?? streamLimit)
        .snapshots()
        .map((snapshot) {
          final items =
              snapshot.docs
                  .map((doc) => MediaItem.fromFirestore(doc.data(), doc.id))
                  .where((i) => i.isCurrentlyWatching)
                  .toList()
                ..sort((a, b) {
                  final aTime = a.progressUpdatedAt ?? a.addedAt;
                  final bTime = b.progressUpdatedAt ?? b.addedAt;
                  return bTime.compareTo(aTime);
                });
          return items;
        });
  }

  /// Couple-scoped currently watching stream.
  Stream<List<MediaItem>> getCoupleCurrentlyWatchingStream({
    String userA = 'khentsgdz',
    String userB = 'clairjassen',
  }) {
    if (AgentMode.isActive.value) return Stream.value(const <MediaItem>[]);
    final controller = StreamController<List<MediaItem>>.broadcast();
    List<MediaItem> itemsA = const [];
    List<MediaItem> itemsB = const [];
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? subA;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? subB;

    void emit() {
      final merged = _mergeCoupleItems(itemsA, itemsB);
      controller.add(merged.where((i) => i.isCurrentlyWatching).toList());
    }

    controller.onListen = () {
      subA = firestore
          .collection('watch_list')
          .where('userName', isEqualTo: userA)
          .limit(streamLimit)
          .snapshots()
          .listen((snapshot) {
            itemsA = snapshot.docs
                .map((doc) => MediaItem.fromFirestore(doc.data(), doc.id))
                .toList();
            emit();
          });
      subB = firestore
          .collection('watch_list')
          .where('userName', isEqualTo: userB)
          .limit(streamLimit)
          .snapshots()
          .listen((snapshot) {
            itemsB = snapshot.docs
                .map((doc) => MediaItem.fromFirestore(doc.data(), doc.id))
                .toList();
            emit();
          });
    };

    controller.onCancel = () async {
      await subA?.cancel();
      await subB?.cancel();
      await controller.close();
    };

    return controller.stream;
  }

  /// Anime-only currently watching for a single user.
  Stream<List<MediaItem>> getCurrentlyWatchingAnimeStream(
    String userName, {
    int? limit,
  }) {
    if (AgentMode.isActive.value) return Stream.value(const <MediaItem>[]);
    if (userName.isEmpty) return Stream.value(const []);
    return firestore
        .collection('watch_list')
        .where('userName', isEqualTo: userName)
        .where('isAnime', isEqualTo: true)
        .limit(limit ?? streamLimit)
        .snapshots()
        .map((snapshot) {
          final items =
              snapshot.docs
                  .map((doc) => MediaItem.fromFirestore(doc.data(), doc.id))
                  .where((i) => i.isAnime && i.isCurrentlyWatching)
                  .toList()
                ..sort((a, b) {
                  final aTime = a.progressUpdatedAt ?? a.addedAt;
                  final bTime = b.progressUpdatedAt ?? b.addedAt;
                  return bTime.compareTo(aTime);
                });
          return items;
        });
  }

  /// Couple-scoped anime currently watching stream.
  Stream<List<MediaItem>> getCoupleCurrentlyWatchingAnimeStream({
    String userA = 'khentsgdz',
    String userB = 'clairjassen',
  }) {
    if (AgentMode.isActive.value) return Stream.value(const <MediaItem>[]);
    final controller = StreamController<List<MediaItem>>.broadcast();
    List<MediaItem> itemsA = const [];
    List<MediaItem> itemsB = const [];
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? subA;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? subB;

    void emit() {
      final merged = _mergeCoupleItems(itemsA, itemsB);
      controller.add(
        merged.where((i) => i.isAnime && i.isCurrentlyWatching).toList(),
      );
    }

    controller.onListen = () {
      subA = firestore
          .collection('watch_list')
          .where('userName', isEqualTo: userA)
          .where('isAnime', isEqualTo: true)
          .limit(streamLimit)
          .snapshots()
          .listen((snapshot) {
            itemsA = snapshot.docs
                .map((doc) => MediaItem.fromFirestore(doc.data(), doc.id))
                .toList();
            emit();
          });
      subB = firestore
          .collection('watch_list')
          .where('userName', isEqualTo: userB)
          .where('isAnime', isEqualTo: true)
          .limit(streamLimit)
          .snapshots()
          .listen((snapshot) {
            itemsB = snapshot.docs
                .map((doc) => MediaItem.fromFirestore(doc.data(), doc.id))
                .toList();
            emit();
          });
    };

    controller.onCancel = () async {
      await subA?.cancel();
      await subB?.cancel();
      await controller.close();
    };

    return controller.stream;
  }

  // ─── Progress ──────────────────────────────────────────────────────────

  /// Keep-alive method to update timestamp while watching (debounced).
  Future<void> heartbeatProgress(
    int catalogId,
    String userName, {
    required String source,
    required String mediaType,
    int? season,
    int? episode,
    int? timestamp,
    int? durationSeconds,
  }) async {
    if (AgentMode.isActive.value) return;
    if (userName.isEmpty) return;
    try {
      final collection = firestore.collection('watch_list');
      final existing = await withGetTimeout(
        collection
            .where('tmdbId', isEqualTo: catalogId)
            .where('userName', isEqualTo: userName)
            .get(),
        label: 'watch progress heartbeat lookup',
      );
      final document = _findCatalogDoc(
        existing,
        id: catalogId,
        source: source,
        mediaType: mediaType,
      );

      // NOTE: no partner fallback (see saveToWatchList). Progress and
      // removals only ever touch the caller's own document; when none
      // exists we create one (progress) or do nothing (remove/
      // heartbeat) instead of hijacking the partner's doc.

      if (document != null) {
        final data = <String, dynamic>{'progressUpdatedAt': Timestamp.now()};
        if (season != null) data['currentSeason'] = season;
        if (episode != null) data['currentEpisode'] = episode;
        if (timestamp != null) data['currentTimestamp'] = timestamp;
        if (durationSeconds != null) data['durationSeconds'] = durationSeconds;
        await collection.doc(document.id).update(data);
      }
    } catch (e) {
      Logger.e('Error heartbeating progress', error: e);
    }
  }

  /// Remove legacy partner-specific statuses from the current user's document
  /// after routing a status update to the partner's document.
  ///
  /// When Khent taps "Clair Watched" and we route to Clair's doc, Khent's
  /// own document may still hold a legacy "watching-clair" value from before
  /// statuses were mapped to self-variants on save. Only those legacy values
  /// are reset to "to-watch" — the user's own watched-self / watching-self
  /// status is always preserved so personal shelves never go empty.
  Future<void> cleanStalePartnerStatus(
    MediaItem item,
    String userName,
    String newStatus,
  ) async {
    if (AgentMode.isActive.value) return;
    try {
      final collection = firestore.collection('watch_list');
      final catalogId = item.tmdbId > 0 ? item.tmdbId : (item.anilistId ?? 0);
      final existing = await withGetTimeout(
        collection
            .where('tmdbId', isEqualTo: catalogId)
            .where('userName', isEqualTo: userName)
            .get(),
        label: 'watchlist stale status lookup',
      );
      final document = _findCatalogDoc(
        existing,
        id: catalogId,
        source: item.source,
        mediaType: item.mediaType,
      );
      if (document == null) return;

      final docData = document.data();
      final currentStatus = docData['status'] as String? ?? '';

      final stalePartner = _companionPartnerStatus(newStatus);
      // Never wipe watched-self / watching-self here: each user's own
      // status powers their personal Currently Watching / Watched shelf,
      // and the dashboard uses per-user streams (not the couple merge),
      // so keeping both partners' statuses is correct. Only clear legacy
      // partner-specific values (e.g. watching-clair) left on this doc
      // from before statuses were mapped to self-variants on save.
      if (stalePartner != null && currentStatus == stalePartner) {
        Logger.d(
          "[WatchList] Cleaning stale '$currentStatus' from $userName's doc",
        );
        await collection.doc(document.id).update({'status': 'to-watch'});
      }
    } catch (e) {
      Logger.e("[WatchList] Error cleaning stale partner status", error: e);
    }
  }

  /// Returns the "watching" counterpart for a "watched" partner status,
  /// or null if there's no stale counterpart to clean.
  ///   "watched-clair" → "watching-clair"
  ///   "watched-khent" → "watching-khent"
  ///   anything else   → null
  static String? _companionPartnerStatus(String status) {
    switch (status) {
      case 'watched-clair':
        return 'watching-clair';
      case 'watched-khent':
        return 'watching-khent';
      case 'watching-clair':
        return 'watched-clair';
      case 'watching-khent':
        return 'watched-khent';
      default:
        return null;
    }
  }

  // ─── Migration ─────────────────────────────────────────────────────────

  /// One-time migration: backfill `userName` for legacy watch_list items that
  /// predate the per-user scoping. Heuristic by status:
  ///   - watched-clair  -> clairjassen
  ///   - watched-khent  -> khentsgdz
  ///   - watched-both / watched / to-watch -> khentsgdz (default)
  Future<int> migrateWatchListOwnership() async {
    if (AgentMode.isActive.value) return 0;
    try {
      final collection = firestore.collection('watch_list');
      final all = await withGetTimeout(
        collection.get(),
        label: 'watchlist ownership migration scan',
      );
      int migrated = 0;
      for (final doc in all.docs) {
        final data = doc.data();
        if ((data['userName'] as String?)?.isNotEmpty == true) continue;
        final status = (data['status'] as String?) ?? 'to-watch';
        String owner;
        if (status == 'watched-clair') {
          owner = 'clairjassen';
        } else if (status == 'watched-khent') {
          owner = 'khentsgdz';
        } else {
          owner = 'khentsgdz';
        }
        await doc.reference.update({'userName': owner});
        migrated++;
      }
      if (migrated > 0) {
        Logger.i(
          "Migrated $migrated legacy watch_list items to user-scoped ownership.",
        );
      }
      return migrated;
    } catch (e) {
      Logger.e("Watchlist migration error", error: e);
      return 0;
    }
  }

  /// "On This Day" — watch list items added on the same month+day in
  /// previous years, for both partners.
  Future<List<MediaItem>> getWatchListFromThisDay() async {
    if (AgentMode.isActive.value) return const [];
    final now = DateTime.now();
    final month = now.month;
    final day = now.day;

    try {
      final m = month.toString().padLeft(2, '0');
      final d = day.toString().padLeft(2, '0');
      var snapshot = await withGetTimeout(
        firestore
            .collection('watch_list')
            .where('monthDay', isEqualTo: '$m-$d')
            .limit(200)
            .get(),
        label: 'watchlist on-this-day',
      );

      // Legacy entries predate the monthDay field; bound the fallback.
      if (snapshot.docs.isEmpty) {
        snapshot = await withGetTimeout(
          firestore
              .collection('watch_list')
              .orderBy('addedAt', descending: true)
              .limit(500)
              .get(),
          label: 'watchlist on-this-day fallback',
        );
      }

      final seen = <String>{};
      final results = <MediaItem>[];
      for (final doc in snapshot.docs) {
        final item = MediaItem.fromFirestore(doc.data(), doc.id);
        if (item.addedAt.month == month &&
            item.addedAt.day == day &&
            item.addedAt.year != now.year &&
            !seen.contains(item.catalogKey)) {
          seen.add(item.catalogKey);
          results.add(item);
        }
      }
      return results;
    } catch (e) {
      Logger.e("Error getting on-this-day watchlist items", error: e);
      return [];
    }
  }

  // ─── Couple merge helpers ──────────────────────────────────────────────

  /// Merges the two partners' watch lists into a single list. Items are
  /// deduplicated by source, media type, and ID; when both partners have the same title the
  /// merged `userName` becomes "userA,userB" and the `status` is the
  /// strongest watched-state across the two (see [_mergeWatchedStatus]).
  static List<MediaItem> _mergeCoupleItems(
    List<MediaItem> itemsA,
    List<MediaItem> itemsB,
  ) {
    final byId = <String, _MergedEntry>{};
    for (final item in itemsA) {
      byId[item.catalogKey] = _MergedEntry(primary: item, partner: null);
    }
    for (final item in itemsB) {
      final key = item.catalogKey;
      final existing = byId[key];
      if (existing == null) {
        byId[key] = _MergedEntry(primary: item, partner: null);
      } else {
        byId[key] = _MergedEntry(primary: existing.primary, partner: item);
      }
    }

    final merged = byId.values.map((entry) {
      if (entry.partner == null) {
        // Single-user item: resolve "watched-self" / "watching-self" to
        // the partner-specific variant so the drawer chips match. "watched-both"
        // / "watching-both" already maps to "Both" as-is, so it comes through
        // unchanged via resolveCoupleStatus and doesn't need the merge path.
        final item = entry.primary;
        final resolved = item.resolveCoupleStatus();
        return resolved != item.status ? item.copyWith(status: resolved) : item;
      }
      final a = entry.primary;
      final b = entry.partner!;
      // If either side already stored "watched-both" / "watching-both" as
      // the single-doc Both representation, the merged status is Both.
      if (a.status == 'watched-both' || b.status == 'watched-both') {
        return a.copyWith(
          userName: '${a.userName},${b.userName}',
          status: 'watched-both',
          isAnime: a.isAnime || b.isAnime,
          addedAt: a.addedAt.isAfter(b.addedAt) ? a.addedAt : b.addedAt,
        );
      }
      if (a.status == 'watching-both' || b.status == 'watching-both') {
        return a.copyWith(
          userName: '${a.userName},${b.userName}',
          status: 'watching-both',
          isAnime: a.isAnime || b.isAnime,
          addedAt: a.addedAt.isAfter(b.addedAt) ? a.addedAt : b.addedAt,
        );
      }
      final userName = '${a.userName},${b.userName}';
      final status = _mergeWatchedStatusForItems(a, b);
      // Use the most recent addedAt so the merged item is positioned
      // correctly in the sorted list.
      final addedAt = a.addedAt.isAfter(b.addedAt) ? a.addedAt : b.addedAt;
      // Anime flag is OR-ed across partners so a title tagged as anime by
      // either partner is considered anime in the merged view.
      final isAnime = a.isAnime || b.isAnime;
      return a.copyWith(
        userName: userName,
        status: status,
        isAnime: isAnime,
        addedAt: addedAt,
      );
    }).toList()..sort((a, b) => b.addedAt.compareTo(a.addedAt));
    return merged;
  }

  /// Returns the strongest watched/watching status across the two partners.
  /// Priority (highest to lowest):
  ///   watched-both > watched-khent/clair > watching-both > watching-khent/clair > to-watch
  ///
  /// Owner-aware: the doc's `userName` is ground truth, not the embedded
  /// suffix in `status`. Legacy docs can still carry a mismatched suffix
  /// (e.g. `watching-khent` on Clair's doc from before statuses were routed
  /// to the owner's doc). Using the suffix would attribute Clair's Odyssey
  /// to Khent; using the owner attributes it to Clair. `isWatched` /
  /// `isCurrentlyWatching` already normalize every variant (self, generic,
  /// partner-specific), so only the owner decides the khent/clair suffix.
  static String _mergeWatchedStatusForItems(MediaItem a, MediaItem b) {
    final aWatched = a.isWatched;
    final bWatched = b.isWatched;
    final aWatching = a.isCurrentlyWatching;
    final bWatching = b.isCurrentlyWatching;

    if (aWatched && bWatched) return 'watched-both';
    if (aWatched) return _ownerStatus(a, 'watched');
    if (bWatched) return _ownerStatus(b, 'watched');
    if (aWatching && bWatching) return 'watching-both';
    if (aWatching) return _ownerStatus(a, 'watching');
    if (bWatching) return _ownerStatus(b, 'watching');
    return 'to-watch';
  }

  /// Maps a single-owner doc to its partner-specific status. `userName` wins
  /// over any embedded suffix so legacy mismatches never leak across rows.
  static String _ownerStatus(MediaItem item, String prefix) {
    final name = item.userName.trim();
    if (name == 'khentsgdz') return '$prefix-khent';
    if (name == 'clairjassen') return '$prefix-clair';
    // Unknown owner (shouldn't happen for per-user queries): preserve an
    // explicit embedded suffix when present, else fall back to generic so
    // shelves (`isWatched` / `isCurrentlyWatching`) still match.
    if (prefix == 'watched') {
      if (item.status == 'watched-clair') return 'watched-clair';
      if (item.status == 'watched-khent') return 'watched-khent';
      return 'watched';
    }
    if (item.status == 'watching-clair') return 'watching-clair';
    if (item.status == 'watching-khent') return 'watching-khent';
    return 'watching';
  }
}

/// Internal helper for [TMDBWatchlistService.getCoupleWatchListStream].
/// Pairs the primary entry with an optional partner entry when both
/// partners have the same catalog identity.
class _MergedEntry {
  final MediaItem primary;
  final MediaItem? partner;
  const _MergedEntry({required this.primary, this.partner});
}
