import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/media_item.dart';
import '../models/our_cinema_item.dart';

/// Persists and syncs the shared "Our Cinema" list between Khent and Clair.
///
/// Firestore layout: a top-level `our_cinema` collection. Each document
/// represents one shared title. Partner-specific watched state is stored as
/// `khentWatchedAt` and `clairWatchedAt` timestamps so the composite status
/// can be derived without a join.
///
/// `addedBy` lets the UI show who originally added a title to the list.
class OurCinemaService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String _collection = 'our_cinema';
  static const String _cacheKey = 'cached_our_cinema';

  /// Allowed partner usernames. The service refuses to write for anyone else.
  static const Set<String> coupleUsernames = {'khentsgdz', 'clairjassen'};

  /// Stream of the entire shared list, newest additions first.
  /// We sort in Dart to avoid needing a composite Firestore index.
  /// Each fresh snapshot is also written to the local cache so the next
  /// cold start can render instantly.
  Stream<List<OurCinemaItem>> getOurCinemaStream() {
    return _firestore
        .collection(_collection)
        .snapshots()
        .map((snapshot) {
      final items = snapshot.docs
          .map((doc) => OurCinemaItem.fromFirestore(doc.data(), doc.id))
          .toList();
      items.sort((a, b) => b.addedAt.compareTo(a.addedAt));
      _writeCache(items);
      return items;
    });
  }

  /// Cached snapshot used to render instantly while Firestore warms up.
  Future<List<OurCinemaItem>> getCachedOurCinema() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null) return [];
      final List decoded = json.decode(raw);
      return decoded.map((data) {
        return OurCinemaItem(
          id: data['id'] ?? '',
          tmdbId: data['tmdbId'] ?? 0,
          title: data['title'] ?? '',
          mediaType: data['mediaType'] ?? 'movie',
          posterPath: data['posterPath'] ?? '',
          backdropPath: data['backdropPath'] ?? '',
          year: data['year'] ?? '',
          addedBy: data['addedBy'] ?? '',
          addedAt: DateTime.tryParse(data['addedAt'] ?? '') ?? DateTime.now(),
          khentWatchedAt: _tryParse(data['khentWatchedAt']),
          clairWatchedAt: _tryParse(data['clairWatchedAt']),
        );
      }).toList();
    } catch (e) {
      print('Error reading cached our_cinema: $e');
      return [];
    }
  }

  Future<void> _writeCache(List<OurCinemaItem> items) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = json.encode(items
          .map((i) => {
                'id': i.id,
                'tmdbId': i.tmdbId,
                'title': i.title,
                'mediaType': i.mediaType,
                'posterPath': i.posterPath,
                'backdropPath': i.backdropPath,
                'year': i.year,
                'addedBy': i.addedBy,
                'addedAt': i.addedAt.toIso8601String(),
                'khentWatchedAt': i.khentWatchedAt?.toIso8601String(),
                'clairWatchedAt': i.clairWatchedAt?.toIso8601String(),
              })
          .toList());
      await prefs.setString(_cacheKey, payload);
    } catch (e) {
      print('Error writing our_cinema cache: $e');
    }
  }

  static DateTime? _tryParse(dynamic value) {
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  /// Add a new title to the shared list. If the title already exists for the
  /// couple (matched by `tmdbId`), this is a no-op — we never create duplicates.
  Future<OurCinemaItem?> addToOurCinema(
      MediaItem item, String addedBy) async {
    if (!coupleUsernames.contains(addedBy)) {
      print('addToOurCinema refused: $addedBy is not a couple user');
      return null;
    }
    try {
      final collection = _firestore.collection(_collection);
      final existing = await collection
          .where('tmdbId', isEqualTo: item.tmdbId)
          .limit(1)
          .get();
      if (existing.docs.isNotEmpty) {
        print('Our Cinema already has ${item.title}, skipping add.');
        return OurCinemaItem.fromFirestore(
            existing.docs.first.data(), existing.docs.first.id);
      }
      final draft = OurCinemaItem(
        id: '',
        tmdbId: item.tmdbId,
        title: item.title,
        mediaType: item.mediaType,
        posterPath: item.posterPath,
        backdropPath: item.backdropPath,
        year: item.year,
        addedBy: addedBy,
        addedAt: DateTime.now(),
      );
      final docRef = await collection.add(draft.toFirestore());
      print('Added "${item.title}" to our_cinema (by $addedBy)');
      return draft.copyWith(id: docRef.id);
    } catch (e) {
      print('Error adding to our_cinema: $e');
      return null;
    }
  }

  /// Toggle the watched flag for one partner on a single shared title.
  /// Setting `watched: true` stamps the per-partner timestamp; `false` clears
  /// it. The other partner's state is untouched.
  Future<void> setWatchedFlag({
    required int tmdbId,
    required String userName,
    required bool watched,
  }) async {
    if (!coupleUsernames.contains(userName)) {
      print('setWatchedFlag refused: $userName is not a couple user');
      return;
    }
    final field = userName == 'khentsgdz'
        ? 'khentWatchedAt'
        : 'clairWatchedAt';
    try {
      final collection = _firestore.collection(_collection);
      final existing = await collection
          .where('tmdbId', isEqualTo: tmdbId)
          .limit(1)
          .get();
      if (existing.docs.isEmpty) {
        print('setWatchedFlag: no our_cinema doc for tmdbId $tmdbId');
        return;
      }
      await collection.doc(existing.docs.first.id).update({
        field: watched ? Timestamp.now() : null,
      });
    } catch (e) {
      print('Error setting watched flag: $e');
    }
  }

  /// Remove a title from the shared list entirely.
  Future<void> removeFromOurCinema(int tmdbId) async {
    try {
      final collection = _firestore.collection(_collection);
      final existing = await collection
          .where('tmdbId', isEqualTo: tmdbId)
          .limit(1)
          .get();
      if (existing.docs.isEmpty) return;
      await collection.doc(existing.docs.first.id).delete();
      print('Removed tmdbId $tmdbId from our_cinema');
    } catch (e) {
      print('Error removing from our_cinema: $e');
    }
  }
}
