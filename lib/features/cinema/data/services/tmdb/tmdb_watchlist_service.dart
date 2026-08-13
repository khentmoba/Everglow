import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../../core/utils/connectivity_aware.dart';
import '../../../../../core/utils/error_aware.dart';
import '../../../../../core/utils/logger.dart';
import '../../models/media_item.dart';
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
    String? statusOwner,
  }) async {
    if (userName.isEmpty) {
      Logger.w("Error saving to watch list: userName is empty");
      return;
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

      // Check if the owner already has this tmdbId
      Logger.d("[WatchList] Querying tmdbId=${item.tmdbId} (${item.tmdbId.runtimeType}), owner=$effectiveOwner, status=$effectiveStatus, title=${item.title}");
      var existing = await collection
          .where('tmdbId', isEqualTo: item.tmdbId)
          .where('userName', isEqualTo: effectiveOwner)
          .limit(1)
          .get();
      Logger.d("[WatchList] Query returned ${existing.docs.length} docs for owner=$effectiveOwner");

      // ── Couple-merge fallback ──────────────────────────────────────
      // When the drawer was opened from a couple-merged stream the item
      // may only exist under the *partner's* userName. If the effective
      // owner has no document yet, look for one under the other partner.
      if (existing.docs.isEmpty) {
        final partner = _resolvePartner(effectiveOwner);
        if (partner != null && partner.isNotEmpty) {
          Logger.d("[WatchList] No doc for $effectiveOwner — checking partner=$partner");
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
        Logger.d("[WatchList] Updating existing doc ${existing.docs.first.id} with status=$effectiveStatus, owner=$effectiveOwner");
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
        };
        if (item.posterPath.isNotEmpty) {
          updateData['posterPath'] = item.posterPath;
        }
        await collection.doc(existing.docs.first.id).update(updateData);
        Logger.d("[WatchList] Update succeeded for doc ${existing.docs.first.id}");
      } else {
        // Create new entry scoped to the effective owner
        Logger.d("[WatchList] No existing doc found — creating new entry for owner=$effectiveOwner");
        await collection.add(item
            .copyWith(
              status: effectiveStatus,
              isAnime: isAnime,
              userName: effectiveOwner,
              addedAt: DateTime.now(),
            )
            .toFirestore());
        Logger.d("[WatchList] New entry created successfully");
      }
      Logger.i("Saved to watch list successfully: ${item.title} ($effectiveOwner, status=$effectiveStatus)");
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

  /// Maps partner-specific statuses to the "self" variant that should be
  /// stored on the owner's document.
  ///   "watched-clair"  → "watched-self"
  ///   "watched-khent"  → "watched-self"
  ///   "watching-clair" → "watching-self"
  ///   "watching-khent" → "watching-self"
  ///   "watched-both"   → "watched-self"
  ///   "watching-both"  → "watching-self"
  ///   anything else    → as-is
  static String _toSelfStatus(String status) {
    switch (status) {
      case 'watched-clair':
      case 'watched-khent':
      case 'watched-both':
        return 'watched-self';
      case 'watching-clair':
      case 'watching-khent':
      case 'watching-both':
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

  /// Remove stale partner-specific statuses from the current user's document
  /// after routing a status update to the partner's document.
  ///
  /// When Khent taps "Clair Watched" and we route to Clair's doc, Khent's
  /// own document may still have "watching-clair" — a stale partner-specific
  /// status that would pollute the couple merge. This resets it to "to-watch".
  Future<void> cleanStalePartnerStatus(
    int tmdbId,
    String userName,
    String newStatus,
  ) async {
    try {
      final collection = firestore.collection('watch_list');
      final existing = await collection
          .where('tmdbId', isEqualTo: tmdbId)
          .where('userName', isEqualTo: userName)
          .limit(1)
          .get();
      if (existing.docs.isEmpty) return;

      final docData = existing.docs.first.data();
      final currentStatus = docData['status'] as String? ?? '';

      // Determine which partner-specific statuses to clear.
      // If newStatus is "watched-clair", clear any "watching-clair" from
      // the current user's doc (since Clair is no longer "just watching").
      //
      // Also clear "watched-self" / "watching-self" — these are the
      // standard stored variants, and leaving them behind when routing
      // a status to the partner would make the couple merge think both
      // partners have the item (causing it to appear in both shelves).
      final stalePartner = _companionPartnerStatus(newStatus);
      final isSelfStatus = currentStatus == 'watched-self' ||
          currentStatus == 'watching-self';
      if ((stalePartner != null && currentStatus == stalePartner) ||
          isSelfStatus) {
        Logger.d("[WatchList] Cleaning stale '$currentStatus' from $userName's doc");
        await collection.doc(existing.docs.first.id).update({'status': 'to-watch'});
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

  /// One-time cleanup: remove Khent's watchlist entries for items where
  /// Clair also has the item with a "watched-self" status. These were
  /// created by a bug that saved partner-specific statuses to the wrong
  /// user's document.
  ///
  /// Returns the number of entries removed.
  Future<int> cleanupDuplicatePartnerEntries() async {
    try {
      final collection = firestore.collection('watch_list');

      // Get all of Khent's entries
      final khentDocs = await collection
          .where('userName', isEqualTo: 'khentsgdz')
          .get();

      // Get all of Clair's entries
      final clairDocs = await collection
          .where('userName', isEqualTo: 'clairjassen')
          .get();

      // Build a set of tmdbIds that Clair has with "watched-self"
      final clairWatchedIds = <int>{};
      for (final doc in clairDocs.docs) {
        final data = doc.data();
        if (data['status'] == 'watched-self') {
          clairWatchedIds.add(data['tmdbId'] as int);
        }
      }

      // Delete Khent's entries that match Clair's watched items
      int deleted = 0;
      for (final doc in khentDocs.docs) {
        final data = doc.data();
        final tmdbId = data['tmdbId'] as int?;
        final status = data['status'] as String?;
        if (tmdbId != null &&
            clairWatchedIds.contains(tmdbId) &&
            (status == 'watched-self' || status == 'watching-clair')) {
          Logger.d("[Cleanup] Removing Khent's doc ${doc.id} for tmdbId=$tmdbId (status=$status) — Clair already has watched-self");
          await doc.reference.delete();
          deleted++;
        }
      }

      if (deleted > 0) {
        Logger.i("[Cleanup] Removed $deleted duplicate entries from Khent's watchlist");
      } else {
        Logger.i("[Cleanup] No duplicate entries found");
      }
      return deleted;
    } catch (e) {
      Logger.e("[Cleanup] Error during cleanup", error: e);
      return 0;
    }
  }

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


  /// "On This Day" — watch list items added on the same month+day in
  /// previous years, for both partners.
  Future<List<MediaItem>> getWatchListFromThisDay() async {
    final now = DateTime.now();
    final month = now.month;
    final day = now.day;

    try {
      final m = month.toString().padLeft(2, '0');
      final d = day.toString().padLeft(2, '0');
      var snapshot = await firestore
          .collection('watch_list')
          .where('monthDay', isEqualTo: '$m-$d')
          .limit(200)
          .get();

      // Legacy entries predate the monthDay field; bound the fallback.
      if (snapshot.docs.isEmpty) {
        snapshot = await firestore
            .collection('watch_list')
            .orderBy('addedAt', descending: true)
            .limit(500)
            .get();
      }

      final seen = <int>{};
      final results = <MediaItem>[];
      for (final doc in snapshot.docs) {
        final item = MediaItem.fromFirestore(doc.data(), doc.id);
        if (item.addedAt.month == month &&
            item.addedAt.day == day &&
            item.addedAt.year != now.year &&
            !seen.contains(item.tmdbId)) {
          seen.add(item.tmdbId);
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
      if (entry.partner == null) {
        // Single-user item: resolve "watched-self" / "watching-self" to
        // the partner-specific variant so the drawer chips match.
        final item = entry.primary;
        final resolved = item.resolveCoupleStatus();
        return resolved != item.status
            ? item.copyWith(status: resolved)
            : item;
      }
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
