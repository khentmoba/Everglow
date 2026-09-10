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
  });
}
