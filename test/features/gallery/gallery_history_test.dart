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
      expect((await service.getPhotosStream().first).length, 40);
      expect((await service.getPhotosStream(limit: 80).first).length, 80);
      expect((await service.searchPhotos('seaside')).single.id, '0');
      expect(query.reads.limits, [40, 80, 40, 40, 40]);
    },
  );
}
