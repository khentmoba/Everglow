// Minimal SDK test doubles: no emulator or new mocking dependency required.
// ignore_for_file: subtype_of_sealed_class
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:everglow/features/cinema/data/models/media_item.dart';
import 'package:everglow/features/cinema/data/services/tmdb/tmdb_cache_service.dart';
import 'package:everglow/features/cinema/data/services/tmdb/tmdb_watchlist_service.dart';

class _Db implements FirebaseFirestore {
  final List<Map<String, dynamic>> rows;
  final queries = <Map<String, Object?>>[];
  final writes = <String>[];
  _Db(this.rows);
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) {
    expect(path, 'watch_list');
    return _Query(this, {});
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Query implements CollectionReference<Map<String, dynamic>> {
  final _Db db;
  final Map<String, Object?> filters;
  _Query(this.db, this.filters);
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #where) {
      return _Query(db, {
        ...filters,
        invocation.positionalArguments.first as String:
            invocation.namedArguments[#isEqualTo],
      });
    }
    if (invocation.memberName == #limit) {
      expect(invocation.positionalArguments.single, 1);
      return this;
    }
    if (invocation.memberName == #doc) {
      return _Reference(db, invocation.positionalArguments.single as String);
    }
    if (invocation.memberName == #add) {
      final id = 'new-${db.rows.length}';
      db.rows.add({
        ...invocation.positionalArguments.single as Map<String, dynamic>,
        'id': id,
      });
      db.writes.add(id);
      return Future<DocumentReference<Map<String, dynamic>>>.value(
        _Reference(db, id),
      );
    }
    if (invocation.memberName == #get) {
      db.queries.add(filters);
      final rows = db.rows
          .where((row) => filters.entries.every((e) => row[e.key] == e.value))
          .take(1);
      return Future<QuerySnapshot<Map<String, dynamic>>>.value(
        _Snapshot(rows.map(_Document.new).toList()),
      );
    }
    return super.noSuchMethod(invocation);
  }
}

class _Snapshot implements QuerySnapshot<Map<String, dynamic>> {
  @override
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
  _Snapshot(this.docs);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Document implements QueryDocumentSnapshot<Map<String, dynamic>> {
  final Map<String, dynamic> row;
  _Document(this.row);
  @override
  String get id => row['id'] as String;
  @override
  Map<String, dynamic> data() => row;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Reference implements DocumentReference<Map<String, dynamic>> {
  final _Db db;
  @override
  final String id;
  _Reference(this.db, this.id);
  @override
  Future<void> update(Map<Object, Object?> data) async {
    db.writes.add(id);
    db.rows
        .firstWhere((row) => row['id'] == id)
        .addAll(data.map((key, value) => MapEntry(key.toString(), value)));
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

Map<String, dynamic> _saved(
  String user, {
  int mal = 53,
  int? ani = 120,
  bool anime = true,
}) => {
  'id': 'demo-$user-$mal-$ani-$anime',
  'tmdbId': mal,
  'anilistId': ?ani,
  'userName': user,
  'title': 'Demo Anime',
  'mediaType': 'tv',
  'posterPath': '',
  'isAnime': anime,
  'status': 'watching-self',
  'currentEpisode': 7,
  'currentTimestamp': 360,
  'durationSeconds': 1440,
};

MediaItem _card({
  int mal = 120,
  int? ani = 120,
  bool anime = true,
  int? total,
  int? episode,
}) => MediaItem(
  id: '',
  tmdbId: mal,
  anilistId: ani,
  title: 'Demo Anime',
  mediaType: 'tv',
  posterPath: '',
  status: '',
  isAnime: anime,
  source: anime ? 'jikan' : 'tmdb',
  addedAt: DateTime(2026),
  episodeCount: total,
  currentEpisode: episode,
);

void main() {
  test(
    'a fresh device resolves AniList-only card to the account MAL entry',
    () async {
      final db = _Db([_saved('khentsgdz'), _saved('clairjassen')]);
      final saved = await _Watchlist(
        db,
      ).getSavedProgress(120, 'clairjassen', anilistId: 120);
      expect(saved!.tmdbId, 53);
      expect(saved.currentEpisode, 7);
      expect(saved.resumeSeconds, 360);
      expect(db.queries, [
        {'anilistId': 120, 'userName': 'clairjassen', 'isAnime': true},
      ]);
    },
  );
  test(
    'does not borrow partner progress or confuse a movie ID with MAL',
    () async {
      final db = _Db([
        _saved('khentsgdz'),
        _saved('clairjassen', mal: 120, ani: null, anime: false),
      ]);
      final saved = await _Watchlist(
        db,
      ).getSavedProgress(120, 'clairjassen', anilistId: 120);
      expect(saved, isNull);
      expect(db.queries.every((q) => q['userName'] == 'clairjassen'), true);
    },
  );
  test(
    'AniList read then write updates own anime, not colliding cinema',
    () async {
      final cinema = _saved('clairjassen', mal: 120, ani: null, anime: false);
      final partner = _saved('khentsgdz');
      final originalCinema = Map<String, dynamic>.from(cinema);
      final originalPartner = Map<String, dynamic>.from(partner);
      final anime = _saved('clairjassen');
      final db = _Db([cinema, partner, anime]);
      final service = _Watchlist(db);
      final saved = await service.getSavedProgress(
        120,
        'clairjassen',
        anilistId: 120,
      );
      expect(saved!.tmdbId, 53);

      // The AniList-only route still carries 120 rather than the saved MAL 53.
      await service.updateProgress(
        _card(),
        'clairjassen',
        episode: saved.currentEpisode! + 1,
        timestamp: 480,
        durationSeconds: 1500,
        status: 'watching-clair',
      );
      expect(db.writes, [saved.id]);
      expect(anime['tmdbId'], 53);
      expect(anime['currentEpisode'], 8);
      expect(anime['currentTimestamp'], 480);
      expect(anime['durationSeconds'], 1500);
      expect(anime['status'], 'watching-self');
      expect(cinema, originalCinema);
      expect(partner, originalPartner);
    },
  );

  for (final legacyCinema in [false, true]) {
    test(
      'new anime does not hijack ${legacyCinema ? 'legacy' : 'explicit'} cinema ID',
      () async {
        final cinema = _saved('clairjassen', mal: 120, ani: null, anime: false);
        if (legacyCinema) cinema.remove('isAnime');
        final partner = _saved('khentsgdz');
        final originals = [
          Map<String, dynamic>.from(cinema),
          Map<String, dynamic>.from(partner),
        ];
        final db = _Db([cinema, partner]);
        final service = _Watchlist(db);
        expect(
          await service.getSavedProgress(120, 'clairjassen', anilistId: 120),
          isNull,
        );
        await service.updateProgress(
          _card(mal: 0),
          'clairjassen',
          episode: 1,
          timestamp: 30,
        );
        expect(db.rows.take(2), originals);
        expect(db.rows, hasLength(3));
        expect(db.writes, ['new-2']);
        expect(db.rows.last['isAnime'], isTrue);
        expect(db.rows.last['anilistId'], 120);
        expect(db.rows.last['userName'], 'clairjassen');
      },
    );
  }

  test('conflicting AniList ID is not a numeric fallback match', () async {
    final otherAnime = _saved('clairjassen', mal: 120, ani: 999);
    final original = Map<String, dynamic>.from(otherAnime);
    final db = _Db([otherAnime]);
    final service = _Watchlist(db);
    expect(
      await service.getSavedProgress(120, 'clairjassen', anilistId: 120),
      isNull,
    );
    await service.updateProgress(_card(), 'clairjassen', episode: 1);
    expect(otherAnime, original);
    expect(db.writes, ['new-1']);
    expect(db.rows.last['anilistId'], 120);
  });

  for (final ani in [120, null]) {
    test(
      'anime numeric fallback without saved AniList stays source-scoped ($ani)',
      () async {
        final cinema = _saved('clairjassen', ani: null, anime: false);
        final original = Map<String, dynamic>.from(cinema);
        final anime = _saved('clairjassen', ani: null);
        final db = _Db([cinema, anime]);
        await _Watchlist(
          db,
        ).updateProgress(_card(mal: 53, ani: ani), 'clairjassen', episode: 9);
        expect(db.writes, [anime['id']]);
        expect(anime['currentEpisode'], 9);
        expect(cinema, original);
      },
    );
  }

  test(
    'cinema retains TMDB-first lookup and legacy document behavior',
    () async {
      final cinema = _saved('clairjassen', mal: 120, ani: null, anime: false)
        ..remove('isAnime');
      final anime = _saved('clairjassen');
      final original = Map<String, dynamic>.from(anime);
      final db = _Db([cinema, anime]);
      await _Watchlist(
        db,
      ).updateProgress(_card(anime: false), 'clairjassen', timestamp: 500);
      expect(db.writes, [cinema['id']]);
      expect(cinema['currentTimestamp'], 500);
      expect(cinema.containsKey('isAnime'), isFalse);
      expect(anime, original);
      expect(db.queries, [
        {'tmdbId': 120, 'userName': 'clairjassen'},
      ]);
    },
  );

  test(
    'resume numeric fallback finds anime behind a colliding cinema ID',
    () async {
      final cinema = _saved('clairjassen', ani: null, anime: false);
      final anime = _saved('clairjassen', ani: null);
      final db = _Db([cinema, anime]);
      final saved = await _Watchlist(
        db,
      ).getSavedProgress(53, 'clairjassen', anilistId: 120);
      expect(saved!.id, anime['id']);
      expect(saved.currentEpisode, 7);
    },
  );

  test('an anime AniList lookup cannot select a non-anime record', () async {
    final cinema = _saved('clairjassen', mal: 120, anime: false);
    final original = Map<String, dynamic>.from(cinema);
    final db = _Db([cinema]);
    final service = _Watchlist(db);
    expect(
      await service.getSavedProgress(120, 'clairjassen', anilistId: 120),
      isNull,
    );
    await service.updateProgress(_card(), 'clairjassen', episode: 1);
    expect(cinema, original);
    expect(db.writes, ['new-1']);
  });

  test('finale progress flips watching to watched and persists the total', () async {
    final anime = _saved('clairjassen');
    final db = _Db([anime]);
    await _Watchlist(db).updateProgress(
      _card(total: 12),
      'clairjassen',
      episode: 12,
      timestamp: 1400,
      durationSeconds: 1500,
      status: 'watching-clair',
    );
    expect(anime['status'], 'watched-self');
    expect(anime['currentEpisode'], 12);
    expect(anime['episodeCount'], 12);
  });

  test('new finale doc is created already watched', () async {
    final db = _Db([]);
    await _Watchlist(
      db,
    ).updateProgress(_card(total: 11), 'clairjassen', episode: 11);
    expect(db.rows, hasLength(1));
    expect(db.rows.single['status'], 'watched-self');
    expect(db.rows.single['currentEpisode'], 11);
    expect(db.rows.single['episodeCount'], 11);
  });

  test('non-finale progress keeps watching (rewatch from EP 1)', () async {
    final anime = _saved('clairjassen')
      ..['status'] = 'watched-self'
      ..['currentEpisode'] = 12
      ..['episodeCount'] = 12;
    final db = _Db([anime]);
    await _Watchlist(db).updateProgress(
      _card(total: 12),
      'clairjassen',
      episode: 1,
      status: 'watching-clair',
    );
    expect(anime['status'], 'watching-self');
    expect(anime['currentEpisode'], 1);
  });

  test('explicit to-watch on the finale is not forced back to watched', () async {
    final anime = _saved('clairjassen');
    final db = _Db([anime]);
    await _Watchlist(db).updateProgress(
      _card(total: 12),
      'clairjassen',
      episode: 12,
      status: 'to-watch',
    );
    expect(anime['status'], 'to-watch');
  });

  test('tapping Watching on a completed season restarts it at EP 1', () async {
    final anime = _saved('clairjassen')
      ..['status'] = 'watched-self'
      ..['currentEpisode'] = 12
      ..['episodeCount'] = 12
      ..['currentTimestamp'] = 1400
      ..['durationSeconds'] = 1500;
    final db = _Db([anime]);
    await _Watchlist(db).saveToWatchList(
      _card(mal: 53, total: 12, episode: 12),
      'watching-self',
      'clairjassen',
    );
    expect(anime['status'], 'watching-self');
    expect(anime['currentEpisode'], 1);
    expect(anime['currentTimestamp'], isNull);
    expect(anime['durationSeconds'], isNull);
  });

  test('logged out lookup never reads data', () async {
    final db = _Db([_saved('clairjassen')]);
    expect(
      await _Watchlist(db).getSavedProgress(53, '', anilistId: 120),
      isNull,
    );
    await _Watchlist(db).updateProgress(_card(), '', episode: 1);
    expect(db.queries, isEmpty);
    expect(db.writes, isEmpty);
  });
}
