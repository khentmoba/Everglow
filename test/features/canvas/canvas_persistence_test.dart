// SDK sealed types are implemented only as network-free test doubles.
// ignore_for_file: subtype_of_sealed_class
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:everglow/features/canvas/data/services/canvas_service.dart';
import 'package:everglow/features/canvas/domain/models/doodle_stroke.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../support/firestore_test_fakes.dart';

class _CanvasCollection extends TestCollection {
  _CanvasCollection(int count)
    : super(
        entries: List.generate(count, (i) => {'userId': 'demo', 'points': []}),
      );

  final limits = <int>[];
  final listening = Completer<void>();
  late final changes = StreamController<void>.broadcast(
    onListen: () {
      if (!listening.isCompleted) listening.complete();
    },
  );
  Future<void> dispose() => changes.close();

  @override
  Query<Map<String, dynamic>> limit(int count) {
    limits.add(count);
    return this;
  }

  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> snapshots({
    bool includeMetadataChanges = false,
    ListenSource source = ListenSource.defaultSource,
  }) async* {
    final cap = limits.last;
    yield TestSnapshot(entries.take(cap).toList());
    await for (final _ in changes.stream) {
      yield TestSnapshot(entries.take(cap).toList());
    }
  }

  @override
  Future<DocumentReference<Map<String, dynamic>>> add(
    Map<String, dynamic> data,
  ) async => _SavedStrokeDocument();
}

class _SavedStrokeDocument extends TestDocument {
  @override
  String get id => 'saved-stroke-id';
}

void main() {
  test(
    'canvas loads stroke 301 and stays live when it outgrows the next limit',
    () async {
      final collection = _CanvasCollection(301);
      final service = CanvasService(db: TestFirestore(collection));
      final iterator = StreamIterator(service.getStrokesStream());
      expect(await iterator.moveNext(), isTrue);
      expect(iterator.current, hasLength(301));
      expect(collection.limits, [300, 600]);
      await collection.listening.future;
      collection.entries.addAll(List.generate(299, (_) => {'points': []}));
      collection.changes.add(null);
      expect(await iterator.moveNext(), isTrue);
      expect(iterator.current, hasLength(600));
      expect(collection.limits, [300, 600, 1200]);
      await iterator.cancel();
      await collection.dispose();
    },
  );

  test(
    'saving returns the exact document id for undo without changing the drawing',
    () async {
      final service = CanvasService(db: TestFirestore(_CanvasCollection(0)));
      final original = DoodleStroke(
        id: '',
        userId: 'demo',
        color: '#ffffff',
        strokeWidth: 3,
        points: const [
          {'x': 0.2, 'y': 0.4},
        ],
      );
      final saved = await service.saveStroke(original);
      expect(saved.id, 'saved-stroke-id');
      expect(saved.points, original.points);
      expect(saved.userId, original.userId);
    },
  );
}
