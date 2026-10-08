import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:everglow/core/services/presence_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _Store extends Fake implements FirebaseFirestore {
  final writes = <({String collection, Map<String, dynamic> data})>[];
  int sessions = 0;

  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      _Collection(this, path);
}

// Test-only Firestore doubles record writes without Firebase or a network.
// ignore: subtype_of_sealed_class
class _Collection extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  _Collection(this.store, this.path);
  final _Store store;
  @override
  final String path;

  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) =>
      _Document(store, this.path, path ?? 'session-${++store.sessions}');
}

// ignore: subtype_of_sealed_class
class _Document extends Fake
    implements DocumentReference<Map<String, dynamic>> {
  _Document(this.store, this.collectionPath, this.id);
  final _Store store;
  final String collectionPath;
  @override
  final String id;

  @override
  Future<void> set(Map<String, dynamic> data, [SetOptions? options]) async {
    store.writes.add((collection: collectionPath, data: data));
  }
}

void main() {
  testWidgets('offline stops heartbeat writes; returning resumes one session', (
    tester,
  ) async {
    final store = _Store();
    final presence = PresenceService(firestore: store);
    presence.startHeartbeat(uid: 'demo', username: 'Demo');
    await tester.pump();
    await tester.pump(PresenceService.heartbeatInterval);
    expect(store.sessions, 1);
    await presence.setOffline('demo');
    final offlineWrites = store.writes.length;
    await tester.pump(const Duration(minutes: 6));
    expect(store.writes.length, offlineWrites);
    expect(store.writes.last.data['isOnline'], isFalse);

    presence.startHeartbeat(uid: 'demo', username: 'Demo');
    await tester.pump();
    expect(store.sessions, 1);
    expect(store.writes.any((write) => write.data['isOnline'] == true), isTrue);
    final resumedWrites = store.writes.length;
    await tester.pump(PresenceService.heartbeatInterval);
    expect(store.writes.length, greaterThan(resumedWrites));
    await presence.stopHeartbeat();
  });
}
