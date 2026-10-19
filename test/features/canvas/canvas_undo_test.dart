import 'package:everglow/core/services/auth_service.dart';
import 'package:everglow/core/services/presence_service.dart';
import 'package:everglow/features/canvas/data/services/canvas_service.dart';
import 'package:everglow/features/canvas/domain/models/doodle_stroke.dart';
import 'package:everglow/features/canvas/presentation/screens/canvas_screen.dart';
import 'package:everglow/features/canvas/presentation/widgets/canvas_painter.dart';
import 'package:everglow/features/canvas/presentation/widgets/canvas_toolbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _Auth extends ChangeNotifier implements AuthService {
  @override
  String get uid => 'demo';
  @override
  String? get partnerUid => null;
  @override
  String get partnerName => 'Demo partner';
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Presence implements PresenceService {
  @override
  Future<void> markDoodling(String uid) async {}
  @override
  Future<void> clearDoodling(String uid) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Canvas extends CanvasService {
  final saved = <String, DoodleStroke>{};
  final deleted = <String>[];
  int sequence = 0;
  @override
  Stream<List<DoodleStroke>> getStrokesStream() =>
      Stream.value(saved.values.toList());
  @override
  Stream<List<DoodleStroke>> getLiveStrokesStream() => Stream.value([]);
  @override
  Future<DoodleStroke> saveStroke(DoodleStroke stroke) async {
    final savedStroke = stroke.copyWith(id: 'stroke-${++sequence}');
    saved[savedStroke.id] = savedStroke;
    return savedStroke;
  }

  @override
  Future<void> deleteStroke(String id) async {
    deleted.add(id);
    saved.remove(id);
  }

  @override
  Future<void> updateActiveStroke(String userId, DoodleStroke stroke) async {}
  @override
  Future<void> clearActiveStroke(String userId) async {}
}

void main() {
  testWidgets(
    'undo targets its saved id, even after erasure; redo retains its new id',
    (tester) async {
      final service = _Canvas();
      final auth = _Auth();
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthService>.value(value: auth),
            Provider<PresenceService>.value(value: _Presence()),
          ],
          child: MaterialApp(home: CanvasScreen(canvasService: service)),
        ),
      );
      await tester.pump();
      final start =
          tester.getTopLeft(find.byType(CanvasSurface)) + const Offset(80, 120);
      for (var i = 0; i < 2; i++) {
        await tester.dragFrom(start, const Offset(120, 50));
        await tester.pump();
      }
      expect(service.saved, hasLength(2));
      expect(
        service.saved['stroke-1']!.points.length,
        service.saved['stroke-2']!.points.length,
      );
      await service.deleteStroke('stroke-2');
      tester.widget<CanvasToolbar>(find.byType(CanvasToolbar)).onUndo();
      await tester.pump();
      expect(service.saved.keys, ['stroke-1']);
      expect(service.deleted, ['stroke-2', 'stroke-2']);
      tester.widget<CanvasToolbar>(find.byType(CanvasToolbar)).onRedo();
      await tester.pump();
      expect(service.saved.keys, ['stroke-1', 'stroke-3']);
      tester.widget<CanvasToolbar>(find.byType(CanvasToolbar)).onUndo();
      await tester.pump();
      expect(service.deleted.last, 'stroke-3');
      expect(service.saved.keys, ['stroke-1']);
      await tester.pumpWidget(const SizedBox());
      auth.dispose();
    },
  );
}
