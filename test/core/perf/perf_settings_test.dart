import 'package:everglow/core/perf/perf_hud.dart';
import 'package:everglow/core/perf/perf_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  tearDown(() {
    PerfSettings.debugReset();
  });

  group('PerfSettings.load', () {
    test('reads saved switches', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'perf_frame_meter_v1': true,
        'perf_render_scale_v1': 2.0,
      });
      PerfSettings.debugReset();

      await PerfSettings.load();

      expect(PerfSettings.frameMeter.value, isTrue);
      expect(PerfSettings.renderScale.value, 2.0);
    });

    test('defaults to off and device scale when nothing is saved', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      PerfSettings.debugReset();

      await PerfSettings.load();

      expect(PerfSettings.frameMeter.value, isFalse);
      expect(PerfSettings.renderScale.value, isNull);
    });

    test('url switches override saved values', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'perf_frame_meter_v1': true,
        'perf_render_scale_v1': 2.0,
      });
      PerfSettings.debugReset();

      await PerfSettings.load(
        queryParameters: {'perf': '0', 'dpr': '1.5'},
      );

      expect(PerfSettings.frameMeter.value, isFalse);
      expect(PerfSettings.renderScale.value, 1.5);
    });

    test('ignores an out-of-range render scale', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      PerfSettings.debugReset();

      await PerfSettings.load(queryParameters: {'dpr': '9'});

      expect(PerfSettings.renderScale.value, isNull);
    });
  });

  group('PerfSettings.nextRenderScale', () {
    test('cycles device → 2.0x → 1.5x → device', () {
      expect(PerfSettings.nextRenderScale(null), 2.0);
      expect(PerfSettings.nextRenderScale(3.0), 1.5);
      expect(PerfSettings.nextRenderScale(2.0), 1.5);
      expect(PerfSettings.nextRenderScale(1.5), isNull);
    });
  });

  group('PerfMeterOverlay', () {
    testWidgets('stays out of the tree until the switch is on', (tester) async {
      PerfSettings.frameMeter.value = false;
      await tester.pumpWidget(
        const MaterialApp(home: PerfMeterOverlay(child: Text('clair'))),
      );

      expect(find.text('clair'), findsOneWidget);
      expect(find.byType(PerfHud), findsNothing);

      PerfSettings.frameMeter.value = true;
      await tester.pump();

      expect(find.byType(PerfHud), findsOneWidget);
      expect(find.textContaining('fps'), findsOneWidget);
      expect(find.textContaining('raster'), findsOneWidget);

      // Dispose the meter so its periodic refresh timer is cancelled.
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    });

    testWidgets('shows zeros — never NaN — before any frame lands', (
      tester,
    ) async {
      PerfSettings.frameMeter.value = true;
      await tester.pumpWidget(
        const MaterialApp(home: PerfMeterOverlay(child: Text('clair'))),
      );

      expect(find.textContaining('NaN'), findsNothing);
      expect(find.textContaining('0 fps'), findsOneWidget);

      PerfSettings.frameMeter.value = false;
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    });

    testWidgets('sits bottom-left, clear of the app controls', (tester) async {
      // Regression: it used to sit top-left, exactly over Khent's Creator
      // Studio button, which left no way to reach the screen that turns the
      // meter off again.
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      PerfSettings.frameMeter.value = true;

      await tester.pumpWidget(
        const MaterialApp(home: PerfMeterOverlay(child: Text('clair'))),
      );
      await tester.pump();

      final top = tester.getTopLeft(find.textContaining('fps'));
      expect(top.dy, greaterThan(844 / 2), reason: 'bottom half, not the top');
      expect(top.dx, lessThan(120), reason: 'left side');

      PerfSettings.frameMeter.value = false;
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    });

    testWidgets('can be dragged out of the way', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      PerfSettings.frameMeter.value = true;

      await tester.pumpWidget(
        const MaterialApp(home: PerfMeterOverlay(child: Text('clair'))),
      );
      await tester.pump();

      final before = tester.getTopLeft(find.textContaining('fps'));
      await tester.drag(find.textContaining('fps'), const Offset(120, -500));
      await tester.pump();
      final after = tester.getTopLeft(find.textContaining('fps'));

      // Direction and rough magnitude only: the gesture arena eats a few
      // pixels of the first move before the pan is recognised.
      expect(after.dx, greaterThan(before.dx + 20));
      expect(after.dy, lessThan(before.dy - 300));
      expect(tester.takeException(), isNull);

      // Let the double-tap recogniser's timeout expire before tearing down,
      // otherwise the test binding sees a pending timer.
      await tester.pump(const Duration(milliseconds: 400));
      PerfSettings.frameMeter.value = false;
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    });

    testWidgets('renders the render-scale line', (tester) async {
      // Tap-to-cycle is web-only (it needs a reload to apply), so the tap path
      // itself is covered by PerfSettings.nextRenderScale.
      PerfSettings.frameMeter.value = true;

      await tester.pumpWidget(
        const MaterialApp(home: PerfMeterOverlay(child: Text('clair'))),
      );

      expect(find.textContaining('dpr '), findsOneWidget);

      PerfSettings.frameMeter.value = false;
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    });
  });
}
