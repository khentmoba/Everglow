import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:everglow/features/books/data/services/our_books_service.dart';
import 'package:everglow/features/cinema/data/services/tmdb/tmdb_cache_service.dart';
import 'package:everglow/features/cinema/data/services/tmdb/tmdb_watchlist_service.dart';
import '../../support/firestore_test_fakes.dart';
import '../../support/paged_query_test_fakes.dart';

class _Watchlist extends TMDBWatchlistService {
  _Watchlist(this.db) : super(TMDBCacheService());
  final FirebaseFirestore db;
  @override
  FirebaseFirestore get firestore => db;
}

void main() {
  test(
    'book and anime previews select newest records before their limit',
    () async {
      final query = PagedCollection(
        entries: [
          for (var i = 0; i < 30; i++)
            {
              'title': 'Demo $i',
              'addedBy': 'khentsgdz',
              'userName': 'khentsgdz',
              'tmdbId': i,
              'isAnime': true,
              'addedAt': Timestamp.fromDate(
                DateTime(2026, 2, 1).add(Duration(minutes: i)),
              ),
            },
        ],
      );
      final db = TestFirestore(query);
      final books = await OurBooksService(
        firestore: db,
      ).getOurBooksByAdderPreviewStream('khentsgdz').first;
      final anime = await _Watchlist(
        db,
      ).getPreviewItems('khentsgdz', limit: 24, isAnime: true);
      expect(books.first.title, 'Demo 29');
      expect(anime.first.title, 'Demo 29');
      expect(books.length, 24);
      expect(anime.length, 24);
      expect(query.reads.orders, ['addedAt', 'addedAt']);
    },
  );
}
