// SDK sealed types are implemented only as network-free test doubles.
// ignore_for_file: subtype_of_sealed_class
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Retries a transaction when another write wins before its commit.
class TransactionFirestore implements FirebaseFirestore {
  Map<String, dynamic>? data;
  int revision = 0;
  int retries = 0;
  void Function()? beforeCommit;
  TransactionFirestore([this.data]);
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      TransactionCollection(this);
  @override
  Future<T> runTransaction<T>(
    TransactionHandler<T> handler, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) async {
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      final transaction = TestTransaction(this);
      final result = await handler(transaction);
      final hook = beforeCommit;
      beforeCommit = null;
      hook?.call();
      if (transaction.readRevision != revision) {
        retries++;
        continue;
      }
      for (final write in transaction.writes) {
        write();
      }
      return result;
    }
    throw StateError('transaction contention');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class TransactionCollection
    implements CollectionReference<Map<String, dynamic>> {
  final TransactionFirestore db;
  TransactionCollection(this.db);
  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) =>
      TransactionDocument(db);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class TransactionDocument implements DocumentReference<Map<String, dynamic>> {
  final TransactionFirestore db;
  TransactionDocument(this.db);
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      TransactionCollection(db);
  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([
    GetOptions? options,
  ]) async {
    final snapshot = TransactionSnapshot(db.data);
    await Future<void>.delayed(Duration.zero);
    return snapshot;
  }

  @override
  Future<void> set(Map<String, dynamic> data, [SetOptions? options]) async {
    db.data = Map.of(data);
    db.revision++;
  }

  @override
  Future<void> update(Map<Object, Object?> data) async {
    db.data!.addAll(Map<String, dynamic>.from(data));
    db.revision++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class TransactionSnapshot implements DocumentSnapshot<Map<String, dynamic>> {
  final Map<String, dynamic>? value;
  TransactionSnapshot(Map<String, dynamic>? data)
    : value = data == null ? null : Map.of(data);
  @override
  bool get exists => value != null;
  @override
  Map<String, dynamic>? data() => value;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class TestTransaction implements Transaction {
  final TransactionFirestore db;
  final List<void Function()> writes = [];
  int? readRevision;
  TestTransaction(this.db);
  @override
  Future<DocumentSnapshot<T>> get<T extends Object?>(
    DocumentReference<T> document,
  ) async {
    readRevision = db.revision;
    final snapshot = TransactionSnapshot(db.data);
    await Future<void>.delayed(Duration.zero);
    return snapshot as DocumentSnapshot<T>;
  }

  @override
  Transaction set<T>(
    DocumentReference<T> document,
    T data, [
    SetOptions? options,
  ]) {
    writes.add(() {
      db.data = Map<String, dynamic>.from(data as Map);
      db.revision++;
    });
    return this;
  }

  @override
  Transaction update(DocumentReference document, Map<String, dynamic> data) {
    writes.add(() {
      db.data!.addAll(data);
      db.revision++;
    });
    return this;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
