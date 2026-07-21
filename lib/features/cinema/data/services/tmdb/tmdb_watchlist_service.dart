import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:everglow/core/utils/connectivity_aware.dart';
import 'package:everglow/core/utils/error_aware.dart';
import 'package:everglow/core/utils/logger.dart';
import 'package:everglow/features/cinema/data/models/media_item.dart';
import 'tmdb_base.dart';
import 'tmdb_cache_service.dart';

/// Firestore-backed watchlist CRUD, couple-merge streams, currently-watching
/// streams, progress tracking, and one-time migration helpers.
class TMDBWatchlistService with TMDBBase, ConnectivityAware, ErrorAware {
  final TMDBCacheService _cacheService;

  TMDBWatchlistService(this._cacheService);

  // ─── CRUD ──────────────────────────────────────────────────────────────

  Future<void> saveToWatchList(
    MediaItem item,
    String status,
    String userName, {
    bool? isAnimeOverride,
  }) async {
    if (userName.isEmpty) {
      Logger.w("Error saving to watch list: userName is empty");
      return;
    }
    try {
      final collection = firestore.collection('watch_list');

      // Check if the SAME user already has this tmdbId
      Logger.d("[WatchList] Querying tmdbId=${item.tmdbId} (${item.tmdbId.runtimeType}), userName=$userName, title=${item.title}");
      var existing = await collection
          .where('tmdbId', isEqualTo: item.tmdbId)
          .where('userName', isEqualTo: userName)
          .limit(1)
          .get();
      Logger.d("[WatchList] Query returned ${existing.docs.length} docs for userName=$userName");

      // ── Couple-merge fallback ──────────────────────────────────────
      // When the drawer was opened from a couple-merged stream the item
      // may only exist under the *partner's* userName. If the current
      // user has no document yet, look for one under the partner's name
      // and update *that* instead of creating a duplicate entry.
      if (existing.docs.isEmpty) {
        final partner = _resolvePartner(userName);
        if (partner != null && partner.isNotEmpty) {
          Logger.d("[WatchList] No doc for $userName — checking partner=$partner");
          final partnerDocs = await collection
              .where('tmdbId', isEqualTo: item.tmdbId)
              .where('userName', isEqualTo: partner)
              .limit(1)
              .get();
          if (partnerDocs.docs.isNotEmpty) {
            Logger.d("[WatchList] Found doc under partner $partner — updating that instead");
            existing = partnerDocs;
          }
        }
      }

      // Determine the anime flag. If the caller passed an explicit override
      // (e.g. the episode drawer detected anime via /details), trust it.
      // Otherwise fall back to whatever was already on the item.
      final isAnime = isAnimeOverride ?? item.isAnime;

      if (existing.docs.isNotEmpty) {
        Logger.d("[WatchList] Updating existing doc ${existing.docs.first.id} with status=$status");
        // Update status if exists — also refresh metadata fields so the
        // dashboard cards always have the latest poster, title, etc.
        // (Items saved before posterPath was stored get their poster
        //  on the next status change rather than staying blank forever.)
        //
        // Only overwrite posterPath when the incoming item actually has
        // one — prevents an empty posterPath (e.g. from a stale Jikan
        // search result) from clobbering an already-saved poster.
        final updateData = <String, dynamic>{
          'status': status,
          'isAnime': isAnime,
          'addedAt': Timestamp.now(),
          'backdropPath': item.backdropPath,
          'title': item.title,
          'year': item.year,
          'mediaType': item.mediaType,
        };
        if (item.posterPath.isNotEmpty) {
          updateData['posterPath'] = item.posterPath;
        }
        await collection.doc(existing.docs.first.id).update(updateData);
        Logger.d("[WatchList] Update succeeded for doc ${existing.docs.first.id}");
      } else {
        // Create new entry scoped to this user
        Logger.d("[WatchList] No existing doc found — creating new entry");
        await collection.add(item
            .copyWith(
              status: status,
              isAnime: isAnime,
              userName: userName,
              addedAt: DateTime.now(),
            )
            .toFirestore());
        Logger.d("[WatchList] New entry created successfully");
      }
      Logger.i("Saved to watch list successfully: ${item.title} ($userName)");
    } catch (e, st) {
      Logger.e("Error saving to watch list", error: e);
      Logger.d("[WatchList] Stack trace: $st");
      rethrow; // Let the caller know the save failed so it can revert UI state.
    }
  }

  /// Resolve the partner username for couple users (khentsgdz ↔ clairjassen).
  /// Returns null for non-couple / cinema-only users.
  static String? _resolvePartner(String userName) {
    if (userName == 'khentsgdz') return 'clairjassen';
    if (userName == 'clairjassen') return 'khentsgdz';
    return null;
  }

  /// Update watch progress fields for a specific watch_list item.
  /// Creates the entry first if it doesn't exist (for first-time watch).
  Future<void> updateProgress(
    MediaItem item,
    String userName, {
    int? season,
    int? episode,
    int? timestamp,
    String? status,
  }) async {
    if (userName.isEmpty) return;
    try {
      final collection = firestore.collection('watch_list');
      var existing = await collection
          .where('tmdbId', isEqualTo: item.tmdbId)
          .where('userName', isEqualTo: userName)
          .limit(1)
          .get();

      // Couple-merge fallback: if no doc under current user, check partner.
      if (existing.docs.isEmpty) {
        final partner = _resolvePartner(userName);
        if (partner != null && partner.isNotEmpty) {
          final partnerDocs = await collection
              .where('tmdbId', isEqualTo: item.tmdbId)
              .where('userName', isEqualTo: partner)
              .limit(1)
              .get();
          if (partnerDocs.docs.isNotEmpty) {
            existing = partnerDocs;
          }
        }
      }

      final now = Timestamp.now();
      final data = <String, dynamic>{
        'currentSeason': season,
        'currentEpisode': episode,
        'currentTimestamp': timestamp,
        'progressUpdatedAt': now,
      };
      if (status != null) data['status'] = status;

      if (existing.docs.isNotEmpty) {
        await collection.doc(existing.docs.first.id).update(data);
      } else {
        await collection.add(item
            .copyWith(
              status: status ?? 'watching-self',
              userName: userName,
              addedAt: DateTime.now(),
              currentSeason: season,
              currentEpisode: episode,
              currentTimestamp: timestamp,
              progressUpdatedAt: DateTime.now(),
            )
            .toFirestore());
      }
    } catch (e) {
      Logger.e('Error updating watch progress', error: e);
    }
  }

  Future<void> removeFromWatchList(int tmdbId, String userName) async {
    if (userName.isEmpty) return;
    try {
      final collection = firestore.collection('watch_list');
      var existing = await collection
          .where('tmdbId', isEqualTo: tmdbId)
          .where('userName', isEqualTo: userName)
          .limit(1)
          .get();

      // Couple-merge fallback: if no doc under current user, check partner.
      if (existing.docs.isEmpty) {
        final partner = _resolvePartner(userName);
        if (partner != null && partner.isNotEmpty) {
          final partnerDocs = await collection
              .where('tmdbId', isEqualTo: tmdbId)
              .where('userName', isEqualTo: partner)
              .limit(1)
              .get();
          if (partnerDocs.docs.isNotEmpty) {
            existing = partnerDocs;
          }
        }
      }

      if (existing.docs.isNotEmpty) {
        await collection.doc(existing.docs.first.id).delete();
        Logger.i("Removed from watch list: $tmdbId ($userName)");
      }
    } catch (e) {
      Logger.e("Error removing from watch list", error: e);
      rethrow; // Let the caller know the removal failed so it can revert UI state.
    }
  }

  // ─── Streams ───────────────────────────────────────────────────────────

  /// Stream of watch list items for a specific user (Firestore-based).
  /// We filter+sort in Dart to avoid needing a composite index in Firestore.
  Stream<List<MediaItem>> getWatchListStream(String userName) {
    return firestore
        .collection('watch_list')
        .where('userName', isEqualTo: userName)
        .snapshots()
        .map((snapshot) {
      final items = snapshot.docs
          .map((doc) => MediaItem.fromFirestore(doc.data(), doc.id))
          .toList()
        ..sort((a, b) => b.addedAt.compareTo(a.addedAt));
      // Side effect: Cache the list locally per user
      _cacheService.cacheWatchList(items, userName);
      return items;
    });
  }

  /// Stream of the combined watch list for the couple
  /// (khentsgdz + clairjassen), deduplicated by `tmdbId`.
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
    };

    return controller.stream;
  }

  /// Stream of anime-only items for a single user. Same source collection
  /// (`watch_list`) as the regular stream — we filter by `isAnime == true`
  /// in Dart so the dashboard's Anime rail and the AnimeScreen only show
  /// Japanese animation, no matter where the title was added.
  Stream<List<MediaItem>> getAnimeWatchListStream(String userName) {
    return firestore
        .collection('watch_list')
        .where('userName', isEqualTo: userName)
        .snapshots()
        .map((snapshot) {
      final items = snapshot.docs
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
    };

    return controller.stream;
  }

  /// Stream of currently watching items for a single user.
  Stream<List<MediaItem>> getCurrentlyWatchingStream(String userName) {
    return firestore
        .collection('watch_list')
        .where('userName', isEqualTo: userName)
        .snapshots()
        .map((snapshot) {
      final items = snapshot.docs
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
    };

    return controller.stream;
  }

  /// Anime-only currently watching for a single user.
  Stream<List<MediaItem>> getCurrentlyWatchingAnimeStream(String userName) {
    return firestore
        .collection('watch_list')
        .where('userName', isEqualTo: userName)
        .snapshots()
        .map((snapshot) {
      final items = snapshot.docs
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
    final controller = StreamController<List<MediaItem>>.broadcast();
    List<MediaItem> itemsA = const [];
    List<MediaItem> itemsB = const [];
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? subA;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? subB;

    void emit() {
      final merged = _mergeCoupleItems(itemsA, itemsB);
      controller
          .add(merged.where((i) => i.isAnime && i.isCurrentlyWatching).toList());
    }

    controller.onListen = () {
      subA = firestore
          .collection('watch_list')
          .where('userName', isEqualTo: userA)
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
    };

    return controller.stream;
  }

  // ─── Progress ──────────────────────────────────────────────────────────

  /// Keep-alive method to update timestamp while watching (debounced).
  Future<void> heartbeatProgress(
    int tmdbId,
    String userName, {
    int? season,
    int? episode,
    int? timestamp,
  }) async {
    if (userName.isEmpty) return;
    try {
      final collection = firestore.collection('watch_list');
      var existing = await collection
          .where('tmdbId', isEqualTo: tmdbId)
          .where('userName', isEqualTo: userName)
          .limit(1)
          .get();

      // Couple-merge fallback: if no doc under current user, check partner.
      if (existing.docs.isEmpty) {
        final partner = _resolvePartner(userName);
        if (partner != null && partner.isNotEmpty) {
          final partnerDocs = await collection
              .where('tmdbId', isEqualTo: tmdbId)
              .where('userName', isEqualTo: partner)
              .limit(1)
              .get();
          if (partnerDocs.docs.isNotEmpty) {
            existing = partnerDocs;
          }
        }
      }

      if (existing.docs.isNotEmpty) {
        final data = <String, dynamic>{
          'progressUpdatedAt': Timestamp.now(),
        };
        if (season != null) data['currentSeason'] = season;
        if (episode != null) data['currentEpisode'] = episode;
        if (timestamp != null) data['currentTimestamp'] = timestamp;
        await collection.doc(existing.docs.first.id).update(data);
      }
    } catch (e) {
      Logger.e('Error heartbeating progress', error: e);
    }
  }

  // ─── Migration ─────────────────────────────────────────────────────────

  /// One-time migration: backfill `userName` for legacy watch_list items that
  /// predate the per-user scoping. Heuristic by status:
  ///   - watched-clair  -> clairjassen
  ///   - watched-khent  -> khentsgdz
  ///   - watched-both / watched / to-watch -> khentsgdz (default)
  Future<int> migrateWatchListOwnership() async {
    try {
      final collection = firestore.collection('watch_list');
      final all = await collection.get();
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
            "Migrated $migrated legacy watch_list items to user-scoped ownership.");
      }
      return migrated;
    } catch (e) {
      Logger.e("Watchlist migration error", error: e);
      return 0;
    }
  }

  // ─── Couple merge helpers ──────────────────────────────────────────────

  /// Merges the two partners' watch lists into a single list. Items are
  /// deduplicated by `tmdbId`; when both partners have the same title the
  /// merged `userName` becomes "userA,userB" and the `status` is the
  /// strongest watched-state across the two (see [_mergeWatchedStatus]).
  static List<MediaItem> _mergeCoupleItems(
      List<MediaItem> itemsA, List<MediaItem> itemsB) {
    final byId = <int, _MergedEntry>{};
    for (final item in itemsA) {
      byId[item.tmdbId] = _MergedEntry(primary: item, partner: null);
    }
    for (final item in itemsB) {
      final existing = byId[item.tmdbId];
      if (existing == null) {
        byId[item.tmdbId] = _MergedEntry(primary: item, partner: null);
      } else {
        byId[item.tmdbId] =
            _MergedEntry(primary: existing.primary, partner: item);
      }
    }

    final merged = byId.values.map((entry) {
      if (entry.partner == null) return entry.primary;
      final a = entry.primary;
      final b = entry.partner!;
      final userName = '${a.userName},${b.userName}';
      final status = _mergeWatchedStatus(a.status, b.status);
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
    }).toList()
      ..sort((a, b) => b.addedAt.compareTo(a.addedAt));
    return merged;
  }

  /// Returns the strongest watched/watching status across the two partners.
  /// Priority (highest to lowest):
  ///   watched-both > watched-khent/clair > watching-both > watching-khent/clair > to-watch
  static String _mergeWatchedStatus(String a, String b) {
    bool isWatched(String s) =>
        s == 'watched' ||
        s == 'watched-self' ||
        s == 'watched-khent' ||
        s == 'watched-clair' ||
        s == 'watched-both';
    bool isWatching(String s) =>
        s == 'watching' ||
        s == 'watching-self' ||
        s == 'watching-khent' ||
        s == 'watching-clair' ||
        s == 'watching-both';

    final aWatched = isWatched(a);
    final bWatched = isWatched(b);
    final aWatching = isWatching(a);
    final bWatching = isWatching(b);

    if (aWatched && bWatched) return 'watched-both';
    if (aWatched) {
      if (a == 'watched-clair') return 'watched-clair';
      return 'watched-khent';
    }
    if (bWatched) {
      if (b == 'watched-khent') return 'watched-khent';
      return 'watched-clair';
    }
    if (aWatching && bWatching) return 'watching-both';
    if (aWatching) {
      if (a == 'watching-clair') return 'watching-clair';
      return 'watching-khent';
    }
    if (bWatching) {
      if (b == 'watching-khent') return 'watching-khent';
      return 'watching-clair';
    }
    return 'to-watch';
  }
}

/// Internal helper for [TMDBWatchlistService.getCoupleWatchListStream].
/// Pairs the primary entry with an optional partner entry when both
/// partners have the same `tmdbId`.
class _MergedEntry {
  final MediaItem primary;
  final MediaItem? partner;
  const _MergedEntry({required this.primary, this.partner});
}
