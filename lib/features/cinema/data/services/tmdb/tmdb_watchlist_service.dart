import 'dart:async';
import '../../../../../core/agent/agent_mode.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../../core/utils/connectivity_aware.dart';
import '../../../../../core/utils/firestore_stream_utils.dart';
import '../../../../../core/utils/logger.dart';
import '../../models/media_item.dart';
import 'tmdb_base.dart';

class TMDBWatchlistService with TMDBBase, ConnectivityAware {
  TMDBWatchlistService();

  static const int streamLimit = 500;

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

      final effectiveOwner = statusOwner ?? userName;

      final effectiveStatus = _toSelfStatus(status);

      final catalogId = _catalogId(item);
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

      assert(skipPartnerFallback || !skipPartnerFallback);

      final isAnime = isAnimeOverride ?? item.isAnime;

      if (existingItem != null) {
        Logger.d(
          "[WatchList] Updating existing doc ${existingItem.id} with status=$effectiveStatus, owner=$effectiveOwner",
        );
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
        if (effectiveStatus.startsWith('watching') && item.isSeriesCompleted) {
          updateData['currentEpisode'] = 1;
          updateData['currentTimestamp'] = null;
          updateData['durationSeconds'] = null;
          updateData['progressUpdatedAt'] = Timestamp.now();
        }
        await collection.doc(existingItem.id).update(updateData);
        Logger.d("[WatchList] Update succeeded for doc ${existingItem.id}");
      } else {
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
      rethrow;
    }
  }

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

  static String? resolveStatusOwner(String status, String currentUser) {
    switch (status) {
      case 'watched-clair':
      case 'watching-clair':
        return 'clairjassen';
      case 'watched-khent':
      case 'watching-khent':
        return 'khentsgdz';
      default:
        return null;
    }
  }

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

  Future<void> updateProgress(
    MediaItem item,
    String userName, {
    int? season,
    int? episode,
    int? timestamp,
    int? durationSeconds,
    String? status,
    bool failOnError = false,
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

      final now = Timestamp.now();
      final data = <String, dynamic>{
        'currentSeason': season,
        'currentEpisode': episode,
        'currentTimestamp': timestamp,
        'durationSeconds': durationSeconds,
        'progressUpdatedAt': now,
      };
      var effectiveStatus = status == null ? null : _toSelfStatus(status);
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
      if (failOnError) rethrow;
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

      if (document != null) {
        await collection.doc(document.id).delete();
        Logger.i("Removed from watch list: $catalogId ($userName)");
      }
    } catch (e) {
      Logger.e("Error removing from watch list", error: e);
      rethrow;
    }
  }

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
          return items;
        });
  }

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

  Stream<List<MediaItem>> getCoupleAnimeStream({
    String userA = 'khentsgdz',
    String userB = 'clairjassen',
  }) => getCoupleWatchListStream(
    userA: userA,
    userB: userB,
  ).map((items) => items.where((i) => i.isAnime).toList());

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

  Stream<List<MediaItem>> getCoupleCurrentlyWatchingStream({
    String userA = 'khentsgdz',
    String userB = 'clairjassen',
  }) => getCoupleWatchListStream(
    userA: userA,
    userB: userB,
  ).map((items) => items.where((i) => i.isCurrentlyWatching).toList());

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
        final item = entry.primary;
        final resolved = item.resolveCoupleStatus();
        return resolved != item.status ? item.copyWith(status: resolved) : item;
      }
      final a = entry.primary;
      final b = entry.partner!;
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
      final addedAt = a.addedAt.isAfter(b.addedAt) ? a.addedAt : b.addedAt;
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

  static String _ownerStatus(MediaItem item, String prefix) {
    final name = item.userName.trim();
    if (name == 'khentsgdz') return '$prefix-khent';
    if (name == 'clairjassen') return '$prefix-clair';
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

class _MergedEntry {
  final MediaItem primary;
  final MediaItem? partner;
  const _MergedEntry({required this.primary, this.partner});
}
