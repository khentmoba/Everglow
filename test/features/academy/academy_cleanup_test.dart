// ignore_for_file: subtype_of_sealed_class
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:everglow/features/academy/data/services/academy_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _Db implements FirebaseFirestore {
  final deleted = <String>[];
  Map<String, dynamic>? created;
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      _Matches(this);
  @override
  WriteBatch batch() => _Batch(this);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Matches implements CollectionReference<Map<String, dynamic>> {
  final _Db db;
  final bool stale;
  _Matches(this.db, {this.stale = false});
  @override
  Query<Map<String, dynamic>> where(
    Object field, {
    Object? isEqualTo,
    Object? isLessThan,
    Object? isLessThanOrEqualTo,
    Object? isGreaterThan,
    Object? isGreaterThanOrEqualTo,
    Object? isNotEqualTo,
    Object? arrayContains,
    Iterable<Object?>? arrayContainsAny,
    Iterable<Object?>? whereIn,
    Iterable<Object?>? whereNotIn,
    bool? isNull,
  }) {
    return _Matches(db, stale: stale || field == 'createdAt');
  }

  @override
  Query<Map<String, dynamic>> limit(int count) => this;
  @override
  Future<QuerySnapshot<Map<String, dynamic>>> get([
    GetOptions? options,
  ]) async => _Snapshot(
    stale ? [_Row(db, 'mine', 'my-uid'), _Row(db, 'theirs', 'other-uid')] : [],
  );
  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) =>
      _Ref(db, path ?? 'new-match');
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Snapshot implements QuerySnapshot<Map<String, dynamic>> {
  @override
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
  _Snapshot(this.docs);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Row implements QueryDocumentSnapshot<Map<String, dynamic>> {
  final _Db db;
  @override
  final String id;
  final String host;
  _Row(this.db, this.id, this.host);
  @override
  Map<String, dynamic> data() => {'hostId': host};
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
  Future<void> set(Map<String, dynamic> data, [SetOptions? options]) async =>
      db.created = data;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Batch implements WriteBatch {
  final _Db db;
  final _deletes = <String>[];
  _Batch(this.db);
  @override
  void delete(DocumentReference ref) => _deletes.add(ref.id);
  @override
  Future<void> commit() async {
    if (_deletes.contains('theirs')) throw StateError('permission-denied');
    db.deleted.addAll(_deletes);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('another host stale match cannot block creating my match', () async {
    final db = _Db();
    final match = await AcademyService(firestore: db).joinOrCreateMatch(
      userUid: 'my-uid',
      username: 'demo',
      category: 'engineering',
      questionIds: ['q1'],
    );
    expect(db.deleted, ['mine']);
    expect(db.created?['hostId'], 'my-uid');
    expect(match.questionIds, ['q1']);
  });
}
