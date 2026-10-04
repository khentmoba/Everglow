import 'package:everglow/core/perf/frame_stats.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/scheduler.dart' show FrameTiming;

void main() {
  group('FrameStats', () {
    test(
      'complete frame span includes time not spent building or rastering',
      () {
        final stats = FrameStats();
        stats.addTimings([
          FrameTiming(
            vsyncStart: 0,
            buildStart: 1000,
            buildFinish: 2000,
            rasterStart: 301000,
            rasterFinish: 302000,
            rasterFinishWallTime: 302000,
          ),
        ]);
        expect(stats.avgBuildMs, 1);
        expect(stats.avgRasterMs, 1);
        expect(stats.worstTotalMs, 302);
        expect(stats.jankPercent, 100);
      },
    );

    test('averages and worsts separate build from raster', () {
      final stats = FrameStats(capacity: 10)
        ..add(4, 6)
        ..add(6, 14);

      expect(stats.frameCount, 2);
      expect(stats.avgBuildMs, 5);
      expect(stats.worstBuildMs, 6);
      expect(stats.avgRasterMs, 10);
      expect(stats.worstRasterMs, 14);
      expect(stats.worstTotalMs, 20);
    });

    test('jank counts frames over the 60fps budget', () {
      final stats = FrameStats(capacity: 10)
        ..add(4, 4) // 8ms — fine
        ..add(8, 8) // 16ms — fine
        ..add(9, 9) // 18ms — jank
        ..add(20, 25); // 45ms — over two reference budgets

      expect(stats.jankPercent, 50);
      expect(stats.slowFramePercent, 25);
    });

    test('window only keeps the newest frames', () {
      final stats = FrameStats(capacity: 3);
      for (var i = 0; i < 10; i++) {
        stats.add(i.toDouble(), 0);
      }

      expect(stats.frameCount, 3);
      expect(stats.avgBuildMs, 8); // frames 7, 8, 9
      expect(stats.worstBuildMs, 9);
    });

    test(
      'session outliers survive the rolling window and reset clears them',
      () {
        final stats = FrameStats(capacity: 4)..add(175, 175);
        for (var i = 0; i < 240; i++) {
          stats.add(1, 1);
        }
        expect(stats.worstTotalMs, 2);
        expect(stats.sessionWorstBuildMs, 175);
        expect(stats.sessionWorstRasterMs, 175);
        expect(stats.sessionWorstFrameMs, 350);
        expect(stats.sessionOver200ms, 1);
        expect(stats.sessionOverBudgetPercent, closeTo(100 / 241, 0.001));
        expect(stats.sessionSlowFramePercent, closeTo(100 / 241, 0.001));
        stats.reset();
        expect(stats.sessionWorstBuildMs, 0);
        expect(stats.sessionWorstRasterMs, 0);
        expect(stats.sessionWorstFrameMs, 0);
        expect(stats.sessionOver200ms, 0);
        expect(stats.sessionOverBudgetPercent, 0);
        expect(stats.sessionSlowFramePercent, 0);
      },
    );

    test('reset clears the window', () {
      final stats = FrameStats(capacity: 5)..add(30, 30);
      stats.reset();

      expect(stats.frameCount, 0);
      expect(stats.avgBuildMs, 0);
      expect(stats.jankPercent, 0);
      expect(stats.worstTotalMs, 0);
    });

    test('empty window reports zeros instead of NaN', () {
      final stats = FrameStats();

      expect(stats.avgRasterMs, 0);
      expect(stats.worstRasterMs, 0);
      expect(stats.jankPercent, 0);
      expect(stats.slowFramePercent, 0);
    });
  });

  group('framesPerSecond', () {
    test('counts frames over the elapsed window', () {
      expect(framesPerSecond(60, const Duration(seconds: 1)), 60);
      expect(framesPerSecond(30, const Duration(milliseconds: 500)), 60);
    });

    test('guards zero-length and empty windows', () {
      expect(framesPerSecond(10, Duration.zero), 0);
      expect(framesPerSecond(0, const Duration(seconds: 1)), 0);
    });
  });

  group('PerfSnapshot', () {
    test('mirrors the stats window, rounded', () {
      final stats = FrameStats(capacity: 10)
        ..add(4, 6)
        ..add(9.1234, 18.9876);
      final snapshot = PerfSnapshot.of(
        fps: 59.876,
        stats: stats,
        devicePixelRatio: 3,
        sampleSequence: 7,
      );

      expect(snapshot.toMap(), {
        'fps': 59.88,
        'buildAvgMs': 6.56,
        'buildWorstMs': 9.12,
        'rasterAvgMs': 12.49,
        'rasterWorstMs': 18.99,
        'worstFrameMs': 28.11,
        'jankPercent': 50.0,
        'slowFramePercent': 0.0,
        'frames': 2.0,
        'devicePixelRatio': 3.0,
        'sampleSequence': 7.0,
        'sessionFrames': 2.0,
        'sessionWorstBuildMs': 9.12,
        'sessionWorstRasterMs': 18.99,
        'sessionWorstFrameMs': 28.11,
        'sessionOver200ms': 0.0,
        'sessionOverBudgetPercent': 50.0,
        'sessionSlowFramePercent': 0.0,
      });
    });

    test('totalFrames keeps counting after the window saturates', () {
      // Regression: frameCount is capped at capacity, so differencing it across
      // meter ticks yields 0 once the window fills and the FPS readout dies
      // after ~4s. totalFrames is the monotonic counter the meter must use.
      final stats = FrameStats(capacity: 4);
      for (var i = 0; i < 10; i++) {
        stats.add(1, 1);
      }

      expect(stats.frameCount, 4, reason: 'window stays capped');
      expect(stats.totalFrames, 10, reason: 'lifetime count keeps rising');

      final rate = framesPerSecond(
        stats.totalFrames - 4,
        const Duration(seconds: 1),
      );
      expect(rate, closeTo(6, 0.001));
    });

    test('reset clears both the window and the lifetime counter', () {
      final stats = FrameStats(capacity: 4);
      for (var i = 0; i < 10; i++) {
        stats.add(1, 1);
      }
      stats.reset();

      expect(stats.frameCount, 0);
      expect(stats.totalFrames, 0);
    });
  });
}
