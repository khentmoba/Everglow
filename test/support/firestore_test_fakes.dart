// SDK @sealed types are deliberately implemented only as network-free test doubles.
// ignore_for_file: subtype_of_sealed_class
import 'package:cloud_firestore/cloud_firestore.dart';

/// Network-free Firestore boundary for calendar/journal regression tests.
class TestFirestore implements FirebaseFirestore {
  final TestCollection entries;
  TestFirestore(this.entries);
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) => entries;
  @override
  WriteBatch batch() => TestBatch(entries);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class TestCollection implements CollectionReference<Map<String, dynamic>> {
  final List<Map<String, dynamic>> entries;
  final bool failWrites;
  final List<void> _writes = [];
  int get writeAttempts => _writes.length;
  TestCollection({this.entries = const [], this.failWrites = true});
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
  }) => this;
  @override
  Query<Map<String, dynamic>> orderBy(
    Object field, {
    bool descending = false,
  }) => this;
  @override
  Query<Map<String, dynamic>> limit(int count) => this;
  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> snapshots({
    bool includeMetadataChanges = false,
    ListenSource source = ListenSource.defaultSource,
  }) => Stream.value(TestSnapshot(entries));
  @override
  Future<QuerySnapshot<Map<String, dynamic>>> get([
    GetOptions? options,
  ]) async => TestSnapshot(entries);
  @override
  Future<DocumentReference<Map<String, dynamic>>> add(
    Map<String, dynamic> data,
  ) async {
    _writes.add(null);
    if (failWrites) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
      );
    }
    return TestDocument();
  }

  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) => TestDocument();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class TestBatch implements WriteBatch {
  final TestCollection entries;
  TestBatch(this.entries);
  @override
  void set<T>(DocumentReference<T> document, T data, [SetOptions? options]) {}
  @override
  void update(DocumentReference document, Map<String, dynamic> data) {}
  @override
  Future<void> commit() async {
    entries._writes.add(null);
    if (entries.failWrites) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
      );
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class TestDocument implements DocumentReference<Map<String, dynamic>> {
  @override
  Future<void> update(Map<Object, Object?> data) async =>
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
      );
  @override
  Future<void> delete() async => throw FirebaseException(
    plugin: 'cloud_firestore',
    code: 'permission-denied',
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class TestSnapshot implements QuerySnapshot<Map<String, dynamic>> {
  final List<Map<String, dynamic>> entries;
  TestSnapshot(this.entries);
  @override
  List<QueryDocumentSnapshot<Map<String, dynamic>>> get docs => [
    for (var i = 0; i < entries.length; i++) TestEntry('$i', entries[i]),
  ];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class TestEntry implements QueryDocumentSnapshot<Map<String, dynamic>> {
  @override
  final String id;
  final Map<String, dynamic> entry;
  TestEntry(this.id, this.entry);
  @override
  Map<String, dynamic> data() => entry;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
