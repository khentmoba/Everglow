// SDK sealed types are implemented only as network-free test doubles.
// ignore_for_file: subtype_of_sealed_class
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:everglow/features/entry/data/welcome_gift_service.dart';

void main() {
  test('only a real signed-in Clair session can receive the gift', () {
    String? recipient(
      String? username, {
      bool signedIn = true,
      bool agent = false,
    }) => WelcomeGiftService.recipientUid(
      username: username,
      uid: 'recipient-uid',
      authenticated: signedIn,
      agentSession: agent,
    );
    expect(recipient('clairjassen'), 'recipient-uid');
    for (final username in [null, 'khentsgdz', 'breyan', 'octagram']) {
      expect(recipient(username), isNull);
    }
    expect(recipient('clairjassen', signedIn: false), isNull);
    expect(recipient('clairjassen', agent: true), isNull);
  });

  test('reads only the recipient-owned document and asks the server', () async {
    final db = _Store({'enabled': true, 'html': '<p>A demo note</p>'});
    final service = WelcomeGiftService(firestore: db);
    expect(await service.pendingHtml('clair-uid'), '<p>A demo note</p>');
    expect(db.readPath, 'users/clair-uid/progress/welcome_gift');
    expect(db.source, Source.server);
    expect(db.writes, isEmpty);
  });

  test(
    'missing, disabled, completed, and malformed gifts never show',
    () async {
      for (final data in <Map<String, dynamic>?>[
        null,
        {'enabled': false, 'html': '<p>Demo</p>'},
        {
          'enabled': true,
          'html': '<p>Demo</p>',
          'completedAt': Timestamp.now(),
        },
        {'enabled': true, 'html': ''},
        {'enabled': true, 'html': 12},
      ]) {
        expect(
          await WelcomeGiftService(firestore: _Store(data)).pendingHtml('uid'),
          isNull,
        );
      }
    },
  );

  test('read failures leave the gift unconsumed for a later visit', () async {
    final db = _Store({'enabled': true, 'html': '<p>Demo</p>'})
      ..failReads = true;
    expect(await WelcomeGiftService(firestore: db).pendingHtml('uid'), isNull);
    expect(db.writes, isEmpty);
    expect(db.data?['completedAt'], isNull);
  });

  test(
    'completion writes only a server receipt and a second device skips it',
    () async {
      final db = _Store({'enabled': true, 'html': '<p>Demo</p>'});
      await WelcomeGiftService(firestore: db).complete('clair-uid');
      expect(db.writePath, 'users/clair-uid/progress/welcome_gift');
      expect(db.writes.single.keys, ['completedAt']);
      expect(db.writes.single['completedAt'], isA<FieldValue>());
      expect(db.data?['html'], '<p>Demo</p>');
      expect(
        await WelcomeGiftService(firestore: db).pendingHtml('clair-uid'),
        isNull,
      );
    },
  );

  test('completion errors reach the UI for a retry', () async {
    final db = _Store({'enabled': true, 'html': '<p>Demo</p>'})
      ..failWrites = true;
    await expectLater(
      WelcomeGiftService(firestore: db).complete('uid'),
      throwsStateError,
    );
    expect(db.data?['completedAt'], isNull);
  });
}

class _Store implements FirebaseFirestore {
  Map<String, dynamic>? data;
  _Store(this.data);
  bool failReads = false, failWrites = false;
  Source? source;
  String? readPath, writePath;
  final writes = <Map<Object, Object?>>[];
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      _Collection(this, path);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Collection implements CollectionReference<Map<String, dynamic>> {
  final _Store store;
  @override
  final String path;
  _Collection(this.store, this.path);
  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) =>
      _Document(store, '${this.path}/$path');
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Document implements DocumentReference<Map<String, dynamic>> {
  final _Store store;
  @override
  final String path;
  _Document(this.store, this.path);
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      _Collection(store, '${this.path}/$path');
  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([
    GetOptions? options,
  ]) async {
    store.readPath = path;
    store.source = options?.source;
    if (store.failReads) throw StateError('offline');
    return _Snapshot(store.data);
  }

  @override
  Future<void> update(Map<Object, Object?> data) async {
    store.writePath = path;
    if (store.failWrites) throw StateError('offline');
    store.writes.add(data);
    store.data!['completedAt'] = Timestamp.now();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Snapshot implements DocumentSnapshot<Map<String, dynamic>> {
  final Map<String, dynamic>? _data;
  _Snapshot(this._data);
  @override
  Map<String, dynamic>? data() => _data;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
