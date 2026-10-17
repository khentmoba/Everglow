// SDK Firestore types are exercised through a network-free in-memory fake.
// ignore_for_file: subtype_of_sealed_class
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:everglow/core/utils/optimistic_action.dart';
import 'package:everglow/features/cinema/data/models/media_item.dart';
import 'package:everglow/features/cinema/data/services/tmdb/tmdb_cache_service.dart';
import 'package:everglow/features/cinema/data/services/tmdb/tmdb_watchlist_service.dart';

class _Db implements FirebaseFirestore {
  final rows = <Map<String, dynamic>>[];
  int _nextId = 0;

  _Db(Iterable<Map<String, dynamic>> initial) {
    rows.addAll(initial.map(Map<String, dynamic>.of));
  }

  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      _Query(this, const {});

  @override
  Future<T> runTransaction<T>(
    TransactionHandler<T> handler, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) => handler(_Transaction(this));

  String nextId() => 'new-${_nextId++}';
  Map<String, dynamic>? row(String id) {
    for (final value in rows) {
      if (value['id'] == id) return value;
    }
    return null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Query implements CollectionReference<Map<String, dynamic>> {
  final _Db db;
  final Map<String, Object?> filters;
  final int? maxRows;
  _Query(this.db, this.filters, [this.maxRows]);

  @override
  Query<Map<String, dynamic>> where(
    Object field, {
    Object? isEqualTo,
    Object? isNotEqualTo,
    Object? isLessThan,
    Object? isLessThanOrEqualTo,
    Object? isGreaterThan,
    Object? isGreaterThanOrEqualTo,
    Object? arrayContains,
    Iterable<Object?>? arrayContainsAny,
    Iterable<Object?>? whereIn,
    Iterable<Object?>? whereNotIn,
    bool? isNull,
  }) => _Query(db, {...filters, field as String: isEqualTo}, maxRows);

  @override
  Query<Map<String, dynamic>> limit(int count) => _Query(db, filters, count);

  List<Map<String, dynamic>> _selected() => db.rows
      .where(
        (row) =>
            filters.entries.every((entry) => row[entry.key] == entry.value),
      )
      .take(maxRows ?? db.rows.length)
      .toList();

  @override
  Future<QuerySnapshot<Map<String, dynamic>>> get([
    GetOptions? options,
  ]) async => _QuerySnapshot(_selected().map((row) => _Doc(db, row)).toList());

  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> snapshots({
    bool includeMetadataChanges = false,
    ListenSource source = ListenSource.defaultSource,
  }) => Stream.value(
    _QuerySnapshot(_selected().map((row) => _Doc(db, row)).toList()),
  );

  @override
  Future<DocumentReference<Map<String, dynamic>>> add(
    Map<String, dynamic> data,
  ) async {
    final id = db.nextId();
    db.rows.add({...data, 'id': id});
    return _Ref(db, id);
  }

  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) =>
      _Ref(db, path ?? db.nextId());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _QuerySnapshot implements QuerySnapshot<Map<String, dynamic>> {
  @override
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
  _QuerySnapshot(this.docs);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Doc implements QueryDocumentSnapshot<Map<String, dynamic>> {
  final _Db db;
  final Map<String, dynamic> value;
  _Doc(this.db, this.value);

  @override
  String get id => value['id'] as String;
  @override
  Map<String, dynamic> data() => value;
  @override
  DocumentReference<Map<String, dynamic>> get reference => _Ref(db, id);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Ref implements DocumentReference<Map<String, dynamic>> {
  final _Db db;
  @override
  final String id;
  _Ref(this.db, this.id);

  @override
  Future<void> update(Map<Object, Object?> values) async {
    db
        .row(id)!
        .addAll(values.map((key, value) => MapEntry(key.toString(), value)));
  }

  @override
  Future<void> delete() async => db.rows.removeWhere((row) => row['id'] == id);

  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([
    GetOptions? options,
  ]) async => _Snapshot(db.row(id));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Snapshot implements DocumentSnapshot<Map<String, dynamic>> {
  final Map<String, dynamic>? value;
  _Snapshot(this.value);

  @override
  bool get exists => value != null;
  @override
  String get id => value?['id'] as String? ?? '';
  @override
  Map<String, dynamic>? data() => value;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Transaction implements Transaction {
  final _Db db;
  _Transaction(this.db);

  @override
  Future<DocumentSnapshot<T>> get<T extends Object?>(
    DocumentReference<T> document,
  ) async => _Snapshot(db.row(document.id)) as DocumentSnapshot<T>;

  @override
  Transaction update(DocumentReference document, Map<String, dynamic> data) {
    db.row(document.id)!.addAll(data);
    return this;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Watchlist extends TMDBWatchlistService {
  final _Db db;
  _Watchlist(this.db) : super(TMDBCacheService());
  @override
  FirebaseFirestore get firestore => db;
}

MediaItem _item(
  int id, {
  String source = 'tmdb',
  String mediaType = 'movie',
  bool anime = false,
  int? anilistId,
  String owner = '',
  String status = '',
  int? timestamp,
  int? episode,
  double? rating,
  bool remind = false,
}) => MediaItem(
  id: '',
  tmdbId: id,
  title: '$source $mediaType $id',
  mediaType: mediaType,
  posterPath: '',
  status: status,
  isAnime: anime,
  userName: owner,
  addedAt: DateTime(2025),
  source: source,
  anilistId: anilistId,
  currentTimestamp: timestamp,
  currentEpisode: episode,
  userRating: rating,
  remindMe: remind,
);

Map<String, dynamic> _row(
  String id,
  String owner,
  int catalogId, {
  String source = 'tmdb',
  String mediaType = 'movie',
  bool anime = false,
  int? anilistId,
  String status = 'to-watch',
  int? timestamp,
  int? episode,
  double? rating,
  bool remind = false,
}) => {
  'id': id,
  'userName': owner,
  'tmdbId': catalogId,
  'source': source,
  'mediaType': mediaType,
  'isAnime': anime,
  'anilistId': ?anilistId,
  'title': '$source $mediaType $catalogId',
  'posterPath': '',
  'status': status,
  'addedAt': Timestamp.fromDate(DateTime(2025)),
  'currentTimestamp': ?timestamp,
  'currentEpisode': ?episode,
  'userRating': ?rating,
  if (remind) 'remindMe': true,
};

void main() {
  test(
    'optimistic removal never hides a different catalog sharing the number',
    () {
      final movie = _item(77);
      final tv = _item(77, mediaType: 'tv');
      final mal = _item(77, mediaType: 'tv', source: 'jikan', anime: true);
      final saved = [movie, tv, mal];
      final pending = OptimisticSet<String>()..markRemoved(movie.catalogKey);
      expect(saved.where((item) => !pending.isRemoved(item.catalogKey)), [
        tv,
        mal,
      ]);
      pending.reconcile([tv.catalogKey, mal.catalogKey]);
      expect(pending.hasPendingChanges, isFalse);
      expect(
        [tv, mal].any((item) => item.catalogKey == movie.catalogKey),
        isFalse,
      );
      expect(
        _item(77, anime: true).catalogKey,
        movie.catalogKey,
        reason: 'genre classification does not change the catalog source',
      );
    },
  );

  test(
    'On This Day keeps colliding catalogs and deduplicates only the same title',
    () async {
      final now = DateTime.now();
      final monthDay =
          '${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final db = _Db([
        _row('movie', 'clairjassen', 77),
        _row('movie-partner', 'khentsgdz', 77),
        _row('tv', 'clairjassen', 77, mediaType: 'tv'),
        _row(
          'mal',
          'clairjassen',
          77,
          mediaType: 'tv',
          source: 'jikan',
          anime: true,
        ),
      ]);
      for (final row in db.rows) {
        row['addedAt'] = Timestamp.fromDate(
          DateTime(now.year - 1, now.month, now.day),
        );
        row['monthDay'] = monthDay;
      }
      final items = await _Watchlist(db).getWatchListFromThisDay();
      expect(items.map((item) => item.catalogKey).toSet().length, 3);
      expect(items, hasLength(3));
    },
  );

  test(
    'save and resume select matching source and movie/TV identity',
    () async {
      final db = _Db([
        _row('movie', 'clairjassen', 77),
        _row('tv', 'clairjassen', 77, mediaType: 'tv'),
        _row(
          'mal',
          'clairjassen',
          77,
          source: 'jikan',
          mediaType: 'tv',
          anime: true,
        ),
      ]);
      final service = _Watchlist(db);

      await service.saveToWatchList(
        _item(77, status: 'watched-self'),
        'watched-self',
        'clairjassen',
      );
      await service.saveToWatchList(
        _item(77, mediaType: 'tv', status: 'watching-self'),
        'watching-self',
        'clairjassen',
      );
      await service.saveToWatchList(
        _item(
          77,
          source: 'jikan',
          mediaType: 'tv',
          anime: true,
          status: 'to-watch',
        ),
        'to-watch',
        'clairjassen',
      );

      expect(db.rows, hasLength(3));
      expect(db.row('movie')!['status'], 'watched-self');
      expect(db.row('tv')!['status'], 'watching-self');
      expect(db.row('mal')!['status'], 'to-watch');
      expect(
        (await service.getSavedProgress(
          77,
          'clairjassen',
          source: 'tmdb',
          mediaType: 'movie',
        ))!.id,
        'movie',
      );
      expect(
        (await service.getSavedProgress(
          77,
          'clairjassen',
          source: 'tmdb',
          mediaType: 'tv',
        ))!.id,
        'tv',
      );
      expect(
        (await service.getSavedProgress(
          77,
          'clairjassen',
          source: 'jikan',
          mediaType: 'tv',
          anilistId: 177,
        ))!.id,
        'mal',
      );
    },
  );

  test('all mutations target only the matching catalog identity', () async {
    final db = _Db([
      _row('movie', 'clairjassen', 42, status: 'watching-self', timestamp: 10),
      _row(
        'tv',
        'clairjassen',
        42,
        mediaType: 'tv',
        status: 'watching-self',
        timestamp: 20,
      ),
      _row(
        'mal',
        'clairjassen',
        42,
        source: 'jikan',
        mediaType: 'tv',
        anime: true,
        anilistId: 142,
        status: 'watching-self',
        timestamp: 30,
      ),
    ]);
    final service = _Watchlist(db);

    await service.updateProgress(
      _item(42, mediaType: 'tv', timestamp: 55, episode: 8),
      'clairjassen',
      timestamp: 55,
    );
    expect(db.row('tv')!['currentTimestamp'], 55);
    expect(db.row('movie')!['currentTimestamp'], 10);
    expect(db.row('mal')!['currentTimestamp'], 30);

    await service.heartbeatProgress(
      42,
      'clairjassen',
      source: 'tmdb',
      mediaType: 'movie',
      timestamp: 66,
    );
    expect(db.row('movie')!['currentTimestamp'], 66);
    expect(db.row('tv')!['currentTimestamp'], 55);
    expect(db.row('mal')!['currentTimestamp'], 30);

    final beforeClear = _item(42, status: 'watching-self', timestamp: 66);
    await service.clearWatchProgress(beforeClear, 'clairjassen');
    expect(db.row('movie')!['status'], 'to-watch');
    expect(db.row('movie')!['currentTimestamp'], isNull);
    expect(db.row('tv')!['currentTimestamp'], 55);
    expect(
      await service.restoreWatchProgress(beforeClear, 'clairjassen'),
      isTrue,
    );
    expect(db.row('movie')!['status'], 'watching-self');
    expect(db.row('movie')!['currentTimestamp'], 66);
    expect(db.row('tv')!['currentTimestamp'], 55);

    await service.setUserRating(
      _item(42, mediaType: 'tv'),
      'clairjassen',
      rating: -1,
    );
    expect(db.row('tv')!['userRating'], -1);
    expect(db.row('movie')!.containsKey('userRating'), isFalse);
    expect(db.row('mal')!.containsKey('userRating'), isFalse);

    final mal = _item(
      42,
      source: 'jikan',
      mediaType: 'tv',
      anime: true,
      anilistId: 142,
    );
    await service.setRemindMe(mal, 'clairjassen', value: true);
    expect(db.row('mal')!['remindMe'], isTrue);
    expect(await service.isReminderSet(mal, 'clairjassen'), isTrue);
    expect(await service.isReminderSet(_item(42), 'clairjassen'), isFalse);

    db.row('movie')!['status'] = 'watching-clair';
    await service.cleanStalePartnerStatus(
      _item(42, status: 'watching-clair'),
      'clairjassen',
      'watched-clair',
    );
    expect(db.row('movie')!['status'], 'to-watch');
    expect(db.row('tv')!['status'], 'watching-self');
    expect(db.row('mal')!['status'], 'watching-self');

    await service.removeFromWatchList(mal, 'clairjassen');
    expect(db.row('mal'), isNull);
    expect(db.row('movie'), isNotNull);
    expect(db.row('tv'), isNotNull);
  });

  test('legacy missing source defaults to TMDB, not MAL', () async {
    final legacy = _row(
      'legacy',
      'clairjassen',
      53,
      mediaType: 'tv',
      anime: true,
    )..remove('source');
    final db = _Db([legacy]);
    final service = _Watchlist(db);

    await service.updateProgress(
      _item(53, source: 'jikan', mediaType: 'tv', anime: true),
      'clairjassen',
      episode: 2,
    );
    expect(db.row('legacy')!['currentEpisode'], isNull);
    expect(db.rows, hasLength(2));

    await service.updateProgress(
      _item(53, mediaType: 'tv', anime: true),
      'clairjassen',
      episode: 4,
    );
    expect(db.row('legacy')!['currentEpisode'], 4);
  });

  test(
    'couple merge deduplicates only identical source and media type',
    () async {
      final db = _Db([
        _row('a-movie', 'khentsgdz', 77, status: 'watched-self'),
        _row(
          'a-mal',
          'khentsgdz',
          77,
          source: 'jikan',
          mediaType: 'tv',
          anime: true,
          status: 'watching-self',
        ),
        _row('b-movie', 'clairjassen', 77, status: 'watching-self'),
        _row(
          'b-tv',
          'clairjassen',
          77,
          mediaType: 'tv',
          status: 'watched-self',
        ),
        _row(
          'b-mal',
          'clairjassen',
          77,
          source: 'jikan',
          mediaType: 'tv',
          anime: true,
          status: 'watching-self',
        ),
      ]);
      final merged = await _Watchlist(
        db,
      ).getCoupleWatchListStream().firstWhere((items) => items.length == 3);

      expect(merged.map((item) => '${item.source}/${item.mediaType}').toSet(), {
        'tmdb/movie',
        'tmdb/tv',
        'jikan/tv',
      });
      expect(
        merged
            .singleWhere(
              (item) => item.source == 'tmdb' && item.mediaType == 'movie',
            )
            .userName,
        'khentsgdz,clairjassen',
      );
      expect(
        merged
            .singleWhere(
              (item) => item.source == 'tmdb' && item.mediaType == 'tv',
            )
            .userName,
        'clairjassen',
      );
      expect(
        merged.singleWhere((item) => item.source == 'jikan').userName,
        'khentsgdz,clairjassen',
      );
    },
  );
}
