import 'package:everglow/core/perf/frame_stats.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FrameStats', () {
    test('averages and worsts separate build from raster', () {
      final stats = FrameStats(capacity: 10)..add(4, 6)..add(6, 14);

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
        ..add(20, 25); // 45ms — jank + dropped

      expect(stats.jankPercent, 50);
      expect(stats.droppedPercent, 25);
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
      expect(stats.droppedPercent, 0);
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
      );

      expect(snapshot.toMap(), {
        'fps': 59.88,
        'buildAvgMs': 6.56,
        'buildWorstMs': 9.12,
        'rasterAvgMs': 12.49,
        'rasterWorstMs': 18.99,
        'worstFrameMs': 28.11,
        'jankPercent': 50.0,
        'droppedPercent': 0.0,
        'frames': 2.0,
        'devicePixelRatio': 3.0,
      });
    });
  });
}
