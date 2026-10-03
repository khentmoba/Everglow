import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:everglow/features/cinema/data/services/playback_progress_writer.dart';

void main() {
  testWidgets(
    'continuous ticks save at 15 seconds instead of postponing forever',
    (tester) async {
      final writer = PlaybackProgressWriter();
      final saves = <int>[];
      for (var position = 1; position <= 30; position++) {
        final snapshot = position;
        writer.schedule(() async => saves.add(snapshot));
        await tester.pump(const Duration(seconds: 1));
      }
      expect(saves, [15, 30]);
      await writer.flush();
    },
  );

  testWidgets('exit flushes the latest position and cancels its timer', (
    tester,
  ) async {
    final writer = PlaybackProgressWriter();
    final saves = <int>[];
    writer.schedule(() async => saves.add(25));
    writer.schedule(() async => saves.add(29));
    await writer.flush();
    expect(saves, [29]);
    await tester.pump(const Duration(minutes: 2));
    expect(saves, [29]);
  });

  testWidgets('new episode writes wait behind old episode flushes', (
    tester,
  ) async {
    final writer = PlaybackProgressWriter();
    final pending = Completer<void>();
    final saves = <String>[];
    writer.schedule(() async {
      await pending.future;
      saves.add('S1E1:600');
    });
    final newEpisode = writer.writeNow(() async => saves.add('S1E2:0'));
    await tester.pump();
    expect(saves, isEmpty);
    pending.complete();
    await newEpisode;
    expect(saves, ['S1E1:600', 'S1E2:0']);
  });

  testWidgets('a failed save does not stop later progress writes', (
    tester,
  ) async {
    final writer = PlaybackProgressWriter();
    await writer.writeNow(() => Future.error(StateError('synthetic failure')));
    var saved = false;
    await writer.writeNow(() async => saved = true);
    expect(saved, isTrue);
  });

  test('autoplay is off by default and never skips the last 90 seconds', () {
    for (final position in [0, 2310, 2399]) {
      expect(
        shouldAutoplayNext(
          enabled: true,
          positionSeconds: position,
          durationSeconds: 2400,
        ),
        isFalse,
      );
    }
    expect(
      shouldAutoplayNext(
        enabled: false,
        positionSeconds: 2400,
        durationSeconds: 2400,
      ),
      isFalse,
    );
    expect(
      shouldAutoplayNext(
        enabled: true,
        positionSeconds: 2400,
        durationSeconds: 2400,
      ),
      isTrue,
    );
    expect(
      shouldAutoplayNext(
        enabled: true,
        positionSeconds: 2400,
        durationSeconds: 0,
      ),
      isFalse,
    );
  });
}
