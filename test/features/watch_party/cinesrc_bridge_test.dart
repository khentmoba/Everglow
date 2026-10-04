import 'package:flutter_test/flutter_test.dart';

import 'package:everglow/features/watch_party/data/services/cinesrc_bridge.dart';

void main() {
  group('parseCinesrcEvent', () {
    test('parses ready event', () {
      final event = parseCinesrcEvent({'type': 'cinesrc:ready'});
      expect(event, isNotNull);
      expect(event!.name, 'ready');
      expect(event.currentTime, isNull);
    });

    test('parses play and pause events', () {
      final play = parseCinesrcEvent({'type': 'cinesrc:play'});
      expect(play, isNotNull);
      expect(play!.name, 'play');

      final pause = parseCinesrcEvent({'type': 'cinesrc:pause'});
      expect(pause, isNotNull);
      expect(pause!.name, 'pause');
    });

    test('parses timeupdate with finite positive seconds', () {
      final event = parseCinesrcEvent({
        'type': 'cinesrc:timeupdate',
        'currentTime': 123.45,
      });
      expect(event, isNotNull);
      expect(event!.name, 'timeupdate');
      expect(event.currentTime, closeTo(123.45, 0.001));
    });

    test('parses seeking, seeked, and ended', () {
      final seeking = parseCinesrcEvent({
        'type': 'cinesrc:seeking',
        'currentTime': 42.0,
      });
      expect(seeking?.name, 'seeking');
      expect(seeking?.currentTime, 42.0);

      final seeked = parseCinesrcEvent({
        'type': 'cinesrc:seeked',
        'currentTime': 45.0,
      });
      expect(seeked?.name, 'seeked');
      expect(seeked?.currentTime, 45.0);

      final ended = parseCinesrcEvent({'type': 'cinesrc:ended'});
      expect(ended?.name, 'ended');
    });

    test('parses response event with command and boolean/numeric result', () {
      final boolResp = parseCinesrcEvent({
        'type': 'cinesrc:response',
        'command': 'getPaused',
        'result': true,
      });
      expect(boolResp, isNotNull);
      expect(boolResp!.name, 'response');
      expect(boolResp.command, 'getPaused');
      expect(boolResp.result, isTrue);

      final numResp = parseCinesrcEvent({
        'type': 'cinesrc:response',
        'command': 'getCurrentTime',
        'result': 88.5,
      });
      expect(numResp?.result, 88.5);
    });

    test('rejects non-maps, nulls, and unrelated events', () {
      expect(parseCinesrcEvent(null), isNull);
      expect(parseCinesrcEvent('cinesrc:ready'), isNull);
      expect(parseCinesrcEvent(123), isNull);
      expect(parseCinesrcEvent({'type': 'other:play'}), isNull);
      expect(parseCinesrcEvent({'type': 'cinesrc:unknown'}), isNull);
      expect(parseCinesrcEvent({'other': 'key'}), isNull);
    });

    test('sanitizes non-numeric or negative currentTime', () {
      final event = parseCinesrcEvent({
        'type': 'cinesrc:timeupdate',
        'currentTime': -5.0,
      });
      expect(event, isNotNull);
      expect(event!.currentTime, isNull);

      final stringTime = parseCinesrcEvent({
        'type': 'cinesrc:timeupdate',
        'currentTime': '123',
      });
      expect(stringTime!.currentTime, isNull);
    });
  });

  group('cinesrcCommand', () {
    test('builds command without args', () {
      expect(cinesrcCommand('play'), {
        'type': 'cinesrc:command',
        'command': 'play',
        'args': <Object?>[],
      });
      expect(cinesrcCommand('pause'), {
        'type': 'cinesrc:command',
        'command': 'pause',
        'args': <Object?>[],
      });
    });

    test('builds command with args', () {
      expect(cinesrcCommand('seek', [42.5]), {
        'type': 'cinesrc:command',
        'command': 'seek',
        'args': [42.5],
      });
      expect(cinesrcCommand('setMuted', [true]), {
        'type': 'cinesrc:command',
        'command': 'setMuted',
        'args': [true],
      });
    });
  });

  group('isUserSeek', () {
    test('ignores small differences within threshold', () {
      expect(
        isUserSeek(expectedSeconds: 10.0, reportedSeconds: 11.0),
        isFalse,
      );
      expect(
        isUserSeek(expectedSeconds: 10.0, reportedSeconds: 8.5),
        isFalse,
      );
    });

    test('flags jumps larger than threshold', () {
      expect(
        isUserSeek(expectedSeconds: 10.0, reportedSeconds: 15.0),
        isTrue,
      );
      expect(
        isUserSeek(expectedSeconds: 60.0, reportedSeconds: 10.0),
        isTrue,
      );
    });

    test('custom threshold is respected', () {
      expect(
        isUserSeek(
          expectedSeconds: 10.0,
          reportedSeconds: 10.8,
          thresholdSeconds: 0.5,
        ),
        isTrue,
      );
      expect(
        isUserSeek(
          expectedSeconds: 10.0,
          reportedSeconds: 10.8,
          thresholdSeconds: 1.0,
        ),
        isFalse,
      );
    });
  });
}
