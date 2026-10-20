import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:everglow/features/gallery/data/services/gallery_service.dart';
import '../../support/firestore_test_fakes.dart';
import '../../support/paged_query_test_fakes.dart';

void main() {
  test(
    'older grid pages and search can reach a photo beyond the newest 50',
    () async {
      final query = PagedCollection(
        entries: [
          for (var i = 0; i < 81; i++)
            {
              'caption': i == 0 ? 'our demo seaside memory' : 'demo photo',
              'uploadedAt': Timestamp.fromDate(
                DateTime(2026, 2, 1).add(Duration(minutes: i)),
              ),
            },
        ],
      );
      final service = GalleryService(db: TestFirestore(query));
      final live = await service.getPhotosStream().first;
      expect(live.length, 40);
      final older = await service.fetchOlderPhotos(
        before: live.last.uploadedAt,
      );
      expect(older.items.length, 40);
      final last = await service.fetchOlderPhotos(
        before: older.items.last.uploadedAt,
        cursor: older.nextCursor,
      );
      final ids = {...live, ...older.items, ...last.items}.map((p) => p.id);
      expect(ids.toSet().length, 81, reason: 'every photo once, none missing');
      expect(last.hasMore, isFalse);
      expect((await service.searchPhotos('seaside')).single.id, '0');
      expect((await service.searchPhotos('photo')).length, 80);
      // Live page + two older pages, then the search index read once (3
      // pages) and reused by the second query.
      expect(query.reads.limits, [40, 40, 40, 40, 40, 40]);
    },
  );
}
