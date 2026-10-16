import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:everglow/features/ai/presentation/widgets/canvas_html_view.dart';
import 'package:everglow/features/entry/data/welcome_gift_service.dart';
import 'package:everglow/features/entry/presentation/widgets/welcome_gift_gate.dart';

class _GiftService extends WelcomeGiftService {
  final completed = <String>{};
  final loads = <String>[];
  int saves = 0;
  bool failSave = false;
  Completer<String?>? delayedLoad;
  Completer<void>? delayedSave;
  @override
  Future<String?> pendingHtml(String uid) async {
    loads.add(uid);
    if (delayedLoad != null) return delayedLoad!.future;
    return completed.contains(uid) ? null : '<p>A synthetic gift</p>';
  }

  @override
  Future<void> complete(String uid) async {
    saves++;
    if (failSave) throw StateError('offline');
    await delayedSave?.future;
    completed.add(uid);
  }
}

Widget _app(_GiftService service, {String? uid = 'clair-uid', Key? key}) =>
    MaterialApp(
      home: WelcomeGiftGate(
        key: key,
        recipientUid: uid,
        service: service,
        child: const Scaffold(body: Text('Normal Everglow home')),
      ),
    );

void main() {
  const linux = TargetPlatformVariant({TargetPlatform.linux});

  testWidgets('non-recipient never reads or displays a gift', (tester) async {
    final service = _GiftService();
    await tester.pumpWidget(_app(service, uid: null));
    expect(service.loads, isEmpty);
    expect(find.byType(CanvasHtmlView), findsNothing);
    expect(find.text('Normal Everglow home'), findsOneWidget);
  }, variant: linux);

  testWidgets(
    'Continue waits for the receipt and later visits do not replay',
    (tester) async {
      final service = _GiftService()..delayedSave = Completer<void>();
      await tester.pumpWidget(_app(service));
      await tester.pump();
      expect(find.byType(CanvasHtmlView), findsOneWidget);
      expect(find.text('Continue to Everglow'), findsNothing);
      tester
          .widget<CanvasHtmlView>(find.byType(CanvasHtmlView))
          .onContentFinishedChanged!(true);
      await tester.pump();
      await tester.tap(find.text('Continue to Everglow'));
      await tester.pump();
      expect(find.text('Saving...'), findsOneWidget);
      expect(find.byType(CanvasHtmlView), findsOneWidget);
      service.delayedSave!.complete();
      await tester.pumpAndSettle();
      expect(service.saves, 1);
      expect(find.byType(CanvasHtmlView), findsNothing);
      await tester.pumpWidget(_app(service, key: UniqueKey()));
      await tester.pumpAndSettle();
      expect(find.byType(CanvasHtmlView), findsNothing);
      expect(service.loads.length, 2);
    },
    variant: linux,
  );

  testWidgets('closing before Continue leaves the gift available', (
    tester,
  ) async {
    final service = _GiftService();
    await tester.pumpWidget(_app(service));
    await tester.pump();
    await tester.pumpWidget(_app(service, key: UniqueKey()));
    await tester.pump();
    expect(find.byType(CanvasHtmlView), findsOneWidget);
    expect(service.completed, isEmpty);
    expect(service.saves, 0);
  }, variant: linux);

  testWidgets('failed receipt keeps the gift open and allows a retry', (
    tester,
  ) async {
    final service = _GiftService()..failSave = true;
    await tester.pumpWidget(_app(service));
    await tester.pump();
    tester
        .widget<CanvasHtmlView>(find.byType(CanvasHtmlView))
        .onContentFinishedChanged!(true);
    await tester.pump();
    await tester.tap(find.text('Continue to Everglow'));
    await tester.pumpAndSettle();
    expect(find.textContaining("Couldn't save right now"), findsOneWidget);
    expect(find.byType(CanvasHtmlView), findsOneWidget);
    service.failSave = false;
    await tester.tap(find.text('Continue to Everglow'));
    await tester.pumpAndSettle();
    expect(find.byType(CanvasHtmlView), findsNothing);
    expect(service.saves, 2);
  }, variant: linux);

  testWidgets('reading, restart and recipient change hide Continue', (
    tester,
  ) async {
    final service = _GiftService();
    await tester.pumpWidget(_app(service));
    await tester.pump();
    final report = tester
        .widget<CanvasHtmlView>(find.byType(CanvasHtmlView))
        .onContentFinishedChanged!;
    report(false);
    await tester.pump();
    expect(find.text('Continue to Everglow'), findsNothing);
    report(true);
    await tester.pump();
    expect(find.text('Continue to Everglow'), findsOneWidget);
    report(false);
    await tester.pump();
    expect(find.text('Continue to Everglow'), findsNothing);
    report(true);
    await tester.pump();
    await tester.pumpWidget(_app(service, uid: 'another-recipient'));
    await tester.pump();
    expect(find.text('Continue to Everglow'), findsNothing);
    expect(service.saves, 0);
  }, variant: linux);

  testWidgets('a delayed read cannot reveal the gift after sign-out', (
    tester,
  ) async {
    final service = _GiftService()..delayedLoad = Completer<String?>();
    await tester.pumpWidget(_app(service));
    await tester.pumpWidget(_app(service, uid: null));
    service.delayedLoad!.complete('<p>A private gift</p>');
    await tester.pumpAndSettle();
    expect(find.byType(CanvasHtmlView), findsNothing);
  }, variant: linux);

  for (final size in [const Size(360, 780), const Size(1024, 768)]) {
    testWidgets('phone/tablet gift controls have no overflow at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(_app(_GiftService()));
      await tester.pumpAndSettle();
      expect(find.text('Continue to Everglow'), findsNothing);
      tester
          .widget<CanvasHtmlView>(find.byType(CanvasHtmlView))
          .onContentFinishedChanged!(true);
      await tester.pumpAndSettle();
      expect(find.text('Continue to Everglow'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }, variant: linux);
  }
}
