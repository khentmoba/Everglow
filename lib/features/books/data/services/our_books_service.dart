import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/utils/firestore_stream_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/book_item.dart';
import '../models/our_books_item.dart';
import '../../../../core/utils/logger.dart';

/// Persists and syncs the shared "Our Books" list between Khent and
/// Clair. Mirrors `OurCinemaService` for the cinema feature.
class OurBooksService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String _collection = 'our_books';
  static const String _cacheKey = 'cached_our_books';

  static const Set<String> coupleUsernames = {'khentsgdz', 'clairjassen'};

  Stream<List<OurBooksItem>> getOurBooksStream() {
    return withFirestoreTimeout(
      _firestore.collection(_collection).limit(300).snapshots().map((snapshot) {
        final items = snapshot.docs
            .map((doc) => OurBooksItem.fromFirestore(doc.data(), doc.id))
            .toList();
        items.sort((a, b) => b.addedAt.compareTo(a.addedAt));
        _writeCache(items);
        return items;
      }),
      label: 'our-books',
    );
  }

  /// Stream of "Our Books" entries filtered to the books added by
  /// [adder]. Used by the dashboard's per-partner sub-row so each
  /// partner sees their own additions alongside the other's.
  Stream<List<OurBooksItem>> getOurBooksByAdderStream(String adder) {
    if (adder.isEmpty) return Stream.value(const <OurBooksItem>[]);
    return withFirestoreTimeout(
      _firestore
          .collection(_collection)
          .where('addedBy', isEqualTo: adder)
          .limit(300)
          .snapshots()
          .map((snapshot) {
            final items = snapshot.docs
                .map((doc) => OurBooksItem.fromFirestore(doc.data(), doc.id))
                .toList();
            items.sort((a, b) => b.addedAt.compareTo(a.addedAt));
            return items;
          }),
      label: 'our-books-$adder',
    );
  }

  Future<List<OurBooksItem>> getCachedOurBooks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null) return [];
      final List decoded = json.decode(raw);
      return decoded
          .map(
            (data) => OurBooksItem(
              id: data['id'] ?? '',
              workKey: data['workKey'] ?? '',
              editionKey: data['editionKey'] ?? '',
              iaId: data['iaId'] ?? '',
              title: data['title'] ?? '',
              author: data['author'] ?? '',
              coverUrl: data['coverUrl'] ?? '',
              year: data['year'] ?? '',
              subjects:
                  (data['subjects'] as List?)
                      ?.map((e) => e.toString())
                      .toList() ??
                  const <String>[],
              addedBy: data['addedBy'] ?? '',
              addedAt:
                  DateTime.tryParse(data['addedAt'] ?? '') ?? DateTime.now(),
              khentReadAt: _tryParse(data['khentReadAt']),
              clairReadAt: _tryParse(data['clairReadAt']),
            ),
          )
          .toList();
    } catch (e) {
      Logger.e('Error reading cached our_books', error: e);
      return [];
    }
  }

  Future<void> _writeCache(List<OurBooksItem> items) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = json.encode(
        items
            .map(
              (i) => {
                'id': i.id,
                'workKey': i.workKey,
                'editionKey': i.editionKey,
                'iaId': i.iaId,
                'title': i.title,
                'author': i.author,
                'coverUrl': i.coverUrl,
                'year': i.year,
                'subjects': i.subjects,
                'addedBy': i.addedBy,
                'addedAt': i.addedAt.toIso8601String(),
                'khentReadAt': i.khentReadAt?.toIso8601String(),
                'clairReadAt': i.clairReadAt?.toIso8601String(),
              },
            )
            .toList(),
      );
      await prefs.setString(_cacheKey, payload);
    } catch (e) {
      Logger.e('Error writing our_books cache', error: e);
    }
  }

  static DateTime? _tryParse(dynamic value) {
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  Future<OurBooksItem?> addToOurBooks(BookItem item, String addedBy) async {
    if (!coupleUsernames.contains(addedBy)) {
      Logger.w('addToOurBooks refused: $addedBy is not a couple user');
      return null;
    }
    try {
      final collection = _firestore.collection(_collection);
      final existing = await collection
          .where('workKey', isEqualTo: item.workKey)
          .limit(1)
          .get();
      if (existing.docs.isNotEmpty) {
        return OurBooksItem.fromFirestore(
          existing.docs.first.data(),
          existing.docs.first.id,
        );
      }
      final draft = OurBooksItem(
        id: '',
        workKey: item.workKey,
        editionKey: item.editionKey,
        iaId: item.iaId,
        title: item.title,
        author: item.author,
        coverUrl: item.coverUrl,
        year: item.year,
        subjects: item.subjects,
        addedBy: addedBy,
        addedAt: DateTime.now(),
      );
      final docRef = await collection.add(draft.toFirestore());
      return draft.copyWith(id: docRef.id);
    } catch (e) {
      Logger.e('Error adding to our_books', error: e);
      return null;
    }
  }

  Future<void> setReadFlag({
    required String workKey,
    required String userName,
    required bool read,
  }) async {
    if (!coupleUsernames.contains(userName)) {
      Logger.w('setReadFlag refused: $userName is not a couple user');
      return;
    }
    final field = userName == 'khentsgdz' ? 'khentReadAt' : 'clairReadAt';
    try {
      final collection = _firestore.collection(_collection);
      final existing = await collection
          .where('workKey', isEqualTo: workKey)
          .limit(1)
          .get();
      if (existing.docs.isEmpty) return;
      await collection.doc(existing.docs.first.id).update({
        field: read ? Timestamp.now() : null,
      });
    } catch (e) {
      Logger.e('Error setting read flag', error: e);
    }
  }

  Future<void> removeFromOurBooks(String workKey) async {
    try {
      final collection = _firestore.collection(_collection);
      final existing = await collection
          .where('workKey', isEqualTo: workKey)
          .limit(1)
          .get();
      if (existing.docs.isEmpty) return;
      await collection.doc(existing.docs.first.id).delete();
    } catch (e) {
      Logger.e('Error removing from our_books', error: e);
    }
  }
}
