import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:everglow/features/bucket_list/data/models/bucket_item.dart';
import 'package:everglow/features/dashboard/presentation/widgets/keepsakes_cluster.dart';
import 'package:everglow/features/journal/data/models/journal_entry.dart';

List<BucketItem> _testBucketItems() => [
      BucketItem(
        id: 'b1',
        title: 'YEAR END SIARGAOOOOO',
        category: BucketCategory.travel,
        status: BucketStatus.wish,
        createdBy: 'clair',
        createdAt: DateTime(2026, 9, 1),
      ),
      BucketItem(
        id: 'b2',
        title: 'GETTING A PERSIAN CATTTTT',
        category: BucketCategory.milestone,
        status: BucketStatus.wish,
        createdBy: 'khent',
        createdAt: DateTime(2026, 9, 1),
      ),
      BucketItem(
        id: 'b3',
        title: 'GOING TO JAPAN TOGETHERRR',
        category: BucketCategory.travel,
        status: BucketStatus.wish,
        createdBy: 'clair',
        createdAt: DateTime(2026, 9, 1),
      ),
    ];

List<JournalEntry> _testJournalEntries() => [
      JournalEntry(
        id: 'j1',
        title: 'July 3, 2026',
        content: 'A sweet letter about summer and quiet nights.',
        author: 'clair',
        createdAt: DateTime(2026, 9, 1),
        updatedAt: DateTime(2026, 9, 1),
        category: JournalCategory.daily,
        mood: JournalMood.loved,
        wordCount: 88,
      ),
      JournalEntry(
        id: 'j2',
        title: 'June 26, 2026',
        content: 'Our road trip memory together.',
        author: 'khent',
        createdAt: DateTime(2026, 9, 1),
        updatedAt: DateTime(2026, 9, 1),
        category: JournalCategory.memory,
        mood: JournalMood.happy,
        wordCount: 648,
      ),
      JournalEntry(
        id: 'j3',
        title: 'June 16, 2026',
        content: 'Notes for us.',
        author: 'clair',
        createdAt: DateTime(2026, 9, 1),
        updatedAt: DateTime(2026, 9, 1),
        category: JournalCategory.letter,
        wordCount: 229,
      ),
    ];

Future<void> _pumpCluster(
  WidgetTester tester, {
  required Size size,
  List<BucketItem>? bucketItems,
  List<JournalEntry>? journalEntries,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: KeepsakesCluster(
            bucketStream: Stream.value(bucketItems ?? _testBucketItems()),
            journalStream: Stream.value(journalEntries ?? _testJournalEntries()),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

void main() {
  group('KeepsakesCluster layout', () {
    testWidgets('KeepsakesCluster has no overflow on a 360px phone', (tester) async {
      await _pumpCluster(tester, size: const Size(360, 800));

      expect(find.text('ATELIER  •  KEEPSAKES'), findsOneWidget);
      expect(find.text('Little worlds, just for us'), findsOneWidget);
      expect(find.text('Our Bucket List'), findsOneWidget);
      expect(find.text('Our Journal'), findsOneWidget);
      expect(find.text('YEAR END SIARGAOOOOO'), findsOneWidget);
      expect(find.text('July 3, 2026'), findsOneWidget);

      final clusterRect = tester.getRect(find.byType(KeepsakesCluster));
      expect(clusterRect.right, lessThanOrEqualTo(360.1));
    });

    testWidgets('KeepsakesCluster has no overflow on an 810px tablet', (tester) async {
      await _pumpCluster(tester, size: const Size(810, 1080));

      expect(find.text('Little worlds, just for us'), findsOneWidget);
      expect(find.text('Our Bucket List'), findsOneWidget);
      expect(find.text('Our Journal'), findsOneWidget);
      expect(find.text('YEAR END SIARGAOOOOO'), findsOneWidget);
      expect(find.text('July 3, 2026'), findsOneWidget);

      final clusterRect = tester.getRect(find.byType(KeepsakesCluster));
      expect(clusterRect.right, lessThanOrEqualTo(810.1));
    });

    testWidgets('KeepsakesCluster renders empty states cleanly on phone', (tester) async {
      await _pumpCluster(
        tester,
        size: const Size(360, 800),
        bucketItems: const [],
        journalEntries: const [],
      );

      expect(find.text('Plant our first dream together'), findsOneWidget);
      expect(find.text('Write our first memory together'), findsOneWidget);
    });
  });
}
