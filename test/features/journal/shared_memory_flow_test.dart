// Firestore's SDK interfaces are implemented only as network-free test doubles.
// ignore_for_file: subtype_of_sealed_class
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:everglow/features/calendar/data/services/calendar_service.dart';
import 'package:everglow/features/calendar/domain/models/calendar_event.dart';
import 'package:everglow/features/journal/data/models/journal_entry.dart';
import 'package:everglow/features/journal/data/services/journal_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _Db implements FirebaseFirestore {
  final docs = <String, Map<String, dynamic>>{};
  bool failCommit = false;
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      _Collection(this, path);
  @override
  Future<T> runTransaction<T>(
    TransactionHandler<T> handler, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) async {
    final tx = _Transaction(this);
    final result = await handler(tx);
    if (failCommit) throw StateError('offline');
    for (final write in tx.writes) {
      write();
    }
    return result;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Collection implements CollectionReference<Map<String, dynamic>> {
  final _Db db;
  @override
  final String path;
  _Collection(this.db, this.path);
  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) =>
      _Document(db, '${this.path}/$path');
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Document implements DocumentReference<Map<String, dynamic>> {
  final _Db db;
  @override
  final String path;
  _Document(this.db, this.path);
  @override
  String get id => path.split('/').last;
  @override
  Future<void> update(Map<Object, Object?> patch) async {
    if (db.failCommit) throw StateError('offline');
    _patch(db.docs[path]!, Map<String, dynamic>.from(patch));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void _patch(Map<String, dynamic> data, Map<String, dynamic> patch) {
  for (final field in patch.entries) {
    final parts = field.key.split('.');
    if (parts.length == 2) {
      final map = Map<String, dynamic>.from(data[parts.first] as Map? ?? {});
      map[parts.last] = field.value;
      data[parts.first] = map;
    } else {
      data[field.key] = field.value;
    }
  }
}

class _Snapshot implements DocumentSnapshot<Map<String, dynamic>> {
  @override
  final String id;
  final Map<String, dynamic>? value;
  _Snapshot(this.id, this.value);
  @override
  bool get exists => value != null;
  @override
  Map<String, dynamic>? data() => value == null ? null : Map.of(value!);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Transaction implements Transaction {
  final _Db db;
  final writes = <void Function()>[];
  _Transaction(this.db);
  @override
  Future<DocumentSnapshot<T>> get<T extends Object?>(
    DocumentReference<T> document,
  ) async =>
      _Snapshot(document.id, db.docs[document.path]) as DocumentSnapshot<T>;
  @override
  Transaction set<T>(
    DocumentReference<T> document,
    T data, [
    SetOptions? options,
  ]) {
    writes.add(
      () => db.docs[document.path] = Map<String, dynamic>.from(data as Map),
    );
    return this;
  }

  @override
  Transaction update(DocumentReference document, Map<String, dynamic> data) {
    writes.add(() => _patch(db.docs[document.path]!, data));
    return this;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  CalendarEvent event() => CalendarEvent(
    id: '',
    title: 'Picnic',
    description: 'Bring tea',
    date: DateTime(2026, 10, 20),
    createdBy: 'khentsgdz',
    bucketItemId: 'picnic',
  );

  test(
    'planning a wish saves the event and planned status atomically',
    () async {
      final db = _Db()
        ..docs['bucket_list/picnic'] = {'title': 'Picnic', 'status': 'wish'};
      await CalendarService(db: db).addEvent(event());
      expect(
        db.docs['calendar_events/bucket_picnic']!['bucketItemId'],
        'picnic',
      );
      expect(db.docs['bucket_list/picnic']!['status'], 'planned');
      expect(
        db.docs['bucket_list/picnic']!['dueDate'],
        Timestamp.fromDate(event().date),
      );
      await expectLater(
        CalendarService(db: db).addEvent(event()),
        throwsStateError,
      );
      expect(db.docs.length, 2);
    },
  );

  test(
    'a failed plan commit leaves the wish untouched and creates no event',
    () async {
      final db = _Db()..docs['bucket_list/picnic'] = {'status': 'wish'};
      db.failCommit = true;
      await expectLater(
        CalendarService(db: db).addEvent(event()),
        throwsStateError,
      );
      expect(db.docs['bucket_list/picnic']!['status'], 'wish');
      expect(db.docs.containsKey('calendar_events/bucket_picnic'), isFalse);
    },
  );

  test(
    'wish and calendar reopen one memory and preserve both perspectives',
    () async {
      final db = _Db();
      final service = JournalService(db: db);
      final first = await service.memoryForSource(
        title: 'Picnic',
        author: 'khentsgdz',
        date: DateTime(2026, 10, 20),
        bucketItemId: 'picnic',
      );
      await Future.wait([
        service.savePerspective(first.id, 'khentsgdz', 'The sunset'),
        service.savePerspective(first.id, 'clairjassen', 'The stories'),
      ]);
      await service.addMemoryPhoto(first.id, 'photo-1');
      final again = await service.memoryForSource(
        title: 'Calendar picnic',
        author: 'clairjassen',
        date: DateTime(2026, 10, 20),
        bucketItemId: 'picnic',
        calendarEventId: 'bucket_picnic',
      );
      expect(again.id, first.id);
      expect(again.title, 'Picnic');
      expect(again.calendarEventId, 'bucket_picnic');
      expect(again.photoIds, ['photo-1']);
      expect(again.perspectives, {
        'khentsgdz': 'The sunset',
        'clairjassen': 'The stories',
      });
      expect(db.docs.length, 1);
      final edited = again.copyWith(
        content: 'A lovely evening',
        updatedAt: DateTime.now(),
      );
      await service.update(edited, original: again);
      final saved = JournalEntry.fromMap(db.docs.values.single, again.id);
      expect(saved.photoIds, ['photo-1']);
      expect(saved.perspectives.length, 2);
      expect(saved.bucketItemId, 'picnic');
    },
  );

  test(
    'photo additions enforce the cap and never erase existing photos',
    () async {
      final db = _Db();
      final service = JournalService(db: db);
      final entry = await service.memoryForSource(
        title: 'Trip',
        author: 'khentsgdz',
        date: DateTime.now(),
        bucketItemId: 'trip',
      );
      await service.setMemoryPhotos(entry.id, List.generate(20, (i) => 'p$i'));
      await expectLater(
        service.addMemoryPhoto(entry.id, 'extra'),
        throwsStateError,
      );
      expect((db.docs.values.single['photoIds'] as List).length, 20);
      await service.addMemoryPhoto(entry.id, 'p0');
      expect((db.docs.values.single['photoIds'] as List).length, 20);
      await expectLater(
        service.savePerspective(entry.id, 'guest', 'No'),
        throwsArgumentError,
      );
    },
  );
}
