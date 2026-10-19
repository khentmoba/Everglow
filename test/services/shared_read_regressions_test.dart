// ignore_for_file: subtype_of_sealed_class
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:everglow/features/calendar/data/services/calendar_service.dart';
import 'package:everglow/features/journal/data/services/journal_service.dart';
import 'package:everglow/features/watch_party/data/services/watch_party_chat_service.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/firestore_test_fakes.dart';

class LiveCollection extends TestCollection {
  LiveCollection(this.source);
  final StreamController<QuerySnapshot<Map<String, dynamic>>> source;
  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> snapshots({
    bool includeMetadataChanges = false,
    ListenSource source = ListenSource.defaultSource,
  }) => this.source.stream;
}

// Query options are mutable only in this network-free test double.
// ignore: must_be_immutable
class OrderedCollection extends TestCollection {
  OrderedCollection(List<Map<String, dynamic>> entries)
    : super(entries: entries);
  String field = 'timestamp';
  bool descending = false;
  int? maxResults;
  bool last = false;
  Map<String, dynamic>? after;
  int reads = 0;
  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) =>
      NestedDocument(this);
  @override
  Query<Map<String, dynamic>> orderBy(Object field, {bool descending = false}) {
    this.field = field as String;
    this.descending = descending;
    after = null;
    return this;
  }

  @override
  Query<Map<String, dynamic>> limit(int count) {
    maxResults = count;
    last = false;
    return this;
  }

  @override
  Query<Map<String, dynamic>> limitToLast(int count) {
    maxResults = count;
    last = true;
    return this;
  }

  @override
  Query<Map<String, dynamic>> startAfterDocument(
    DocumentSnapshot documentSnapshot,
  ) {
    after = documentSnapshot.data() as Map<String, dynamic>;
    return this;
  }

  List<Map<String, dynamic>> selected() {
    final sorted = List<Map<String, dynamic>>.of(entries)
      ..sort((a, b) {
        final result = (a[field] as Timestamp).compareTo(b[field] as Timestamp);
        return descending ? -result : result;
      });
    final remaining = after == null
        ? sorted
        : sorted.skip(sorted.indexOf(after!) + 1).toList();
    final n = maxResults ?? remaining.length;
    return last
        ? remaining
              .skip(remaining.length > n ? remaining.length - n : 0)
              .toList()
        : remaining.take(n).toList();
  }

  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> snapshots({
    bool includeMetadataChanges = false,
    ListenSource source = ListenSource.defaultSource,
  }) => Stream.value(TestSnapshot(selected()));
  @override
  Future<QuerySnapshot<Map<String, dynamic>>> get([GetOptions? options]) async {
    reads++;
    return TestSnapshot(selected());
  }
}

class NestedDocument extends TestDocument {
  final OrderedCollection messages;
  NestedDocument(this.messages);
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) => messages;
}

void main() {
  test(
    'late calendar listener receives the loaded event list without another write',
    () async {
      final source =
          StreamController<QuerySnapshot<Map<String, dynamic>>>.broadcast();
      final collection = LiveCollection(source);
      final service = CalendarService(db: TestFirestore(collection));
      final firstResult = Completer<void>();
      var firstEmissions = 0;
      final subscription = service.getUpcomingEvents(days: 60).listen((_) {
        firstEmissions++;
        if (!firstResult.isCompleted) firstResult.complete();
      });
      addTearDown(() async {
        await subscription.cancel();
        await source.close();
      });
      collection.source.add(
        TestSnapshot([
          {
            'title': 'Demo date',
            'date': Timestamp.fromDate(
              DateTime.now().add(const Duration(days: 1)),
            ),
          },
        ]),
      );
      await firstResult.future;
      expect(service.cachedUpcoming, hasLength(1));
      final lateResult = service
          .getUpcomingEvents(days: 60)
          .first
          .timeout(const Duration(milliseconds: 500));
      await expectLater(lateResult, completion(hasLength(1)));
      expect(
        firstEmissions,
        1,
        reason:
            'replaying to a new listener must not notify existing listeners',
      );
      expect(collection.source.hasListener, isTrue);
    },
  );

  test(
    'Watch Together stream includes message 201 just like initial history fetch',
    () async {
      final collection = OrderedCollection([
        for (var i = 1; i <= 201; i++)
          {
            'text': 'message $i',
            'sender': 'demo',
            'senderUid': 'demo',
            'timestamp': Timestamp.fromMillisecondsSinceEpoch(i * 1000),
          },
      ]);
      final service = WatchPartyChatService(
        firestore: TestFirestore(collection),
      );
      final live = await service.getMessagesStream('demo').first;
      final history = await service.getMessages('demo');
      expect(history.last.text, 'message 201');
      expect(live.last.text, history.last.text);
      expect(
        live.map((message) => message.text),
        history.map((message) => message.text),
      );
      expect(live.first.text, 'message 2');
      expect(live, hasLength(200));
    },
  );

  test('journal search finds the oldest of 81 entries', () async {
    final collection = OrderedCollection([
      for (var i = 1; i <= 81; i++)
        {
          'title': i == 1 ? 'unique-old-memory' : 'newer memory $i',
          'content': 'demo',
          'author': 'demo',
          'createdAt': Timestamp.fromMillisecondsSinceEpoch(i * 1000),
        },
    ]);
    final service = JournalService(db: TestFirestore(collection));
    expect(await service.search('newer memory 81'), hasLength(1));
    expect(await service.search('unique-old-memory'), hasLength(1));
  });

  test(
    'journal search reads every page, preserves order, and trims the query',
    () async {
      final collection = OrderedCollection([
        for (var i = 1; i <= 160; i++)
          {
            'title': 'matching memory $i',
            'createdAt': Timestamp.fromMillisecondsSinceEpoch(i * 1000),
          },
      ]);
      final results = await JournalService(
        db: TestFirestore(collection),
      ).search('  MATCHING  ');
      expect(results, hasLength(160));
      expect(results.first.title, 'matching memory 160');
      expect(results.last.title, 'matching memory 1');
      expect(results.map((entry) => entry.title).toSet(), hasLength(160));
      expect(collection.reads, 3);
    },
  );

  test('empty journal searches do not read Firestore', () async {
    final collection = OrderedCollection([]);
    final service = JournalService(db: TestFirestore(collection));
    expect(await service.search('   '), isEmpty);
    expect(collection.reads, 0);
    expect(await service.search('missing'), isEmpty);
    expect(collection.reads, 1);
  });

  test('new Watch Together chats return empty history and streams', () async {
    final service = WatchPartyChatService(
      firestore: TestFirestore(OrderedCollection([])),
    );
    expect(await service.getMessages('demo'), isEmpty);
    expect(await service.getMessagesStream('demo').first, isEmpty);
    expect(await service.getMessagesStream('').first, isEmpty);
  });
}
