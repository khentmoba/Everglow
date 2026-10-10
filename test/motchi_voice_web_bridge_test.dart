@TestOn('browser')
library;

// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:js' as js;

import 'package:everglow/features/ai/presentation/widgets/motchi_web_bridge_web.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late MotchiWebBridge bridge;
  dynamic originalWebkit;
  dynamic originalStandard;

  setUp(() {
    originalWebkit = js.context['webkitSpeechRecognition'];
    originalStandard = js.context['SpeechRecognition'];
    js.context.callMethod('eval', [
      '''window.webkitSpeechRecognition = function() {
        window.motchiTestRecognition = this;
        this.start = function() {};
        this.stop = function() { this.stopped = true; };
        this.abort = function() { this.aborted = true; };
      };''',
    ]);
    bridge = MotchiWebBridge();
  });

  tearDown(() {
    bridge.cancelRecognition();
    js.context['webkitSpeechRecognition'] = originalWebkit;
    js.context['SpeechRecognition'] = originalStandard;
    js.context.deleteProperty('motchiTestRecognition');
  });

  js.JsObject recognition() =>
      js.context['motchiTestRecognition'] as js.JsObject;

  void result(List<String> words, {required bool finalResult}) {
    final results = words.map((word) {
      final result = js.JsObject.jsify([
        {'transcript': word},
      ]);
      result['isFinal'] = finalResult;
      return result;
    }).toList();
    recognition().callMethod('onresult', [
      js.JsObject.jsify({'results': results}),
    ]);
  }

  test(
    'keeps partial speech until listening ends without a final result',
    () async {
      var completed = false;
      final pending = bridge.recognizeOnce().then((value) {
        completed = true;
        return value;
      });
      expect(recognition()['interimResults'], isTrue);
      result(['hello Motchi'], finalResult: false);
      await Future<void>.delayed(Duration.zero);
      expect(completed, isFalse);
      recognition().callMethod('onend', [js.JsObject.jsify({})]);
      expect(await pending, 'hello Motchi');
    },
  );

  test(
    'stop waits for the final result and keeps every result segment',
    () async {
      final pending = bridge.recognizeOnce();
      result(['hello'], finalResult: false);
      bridge.stopRecognition();
      expect(recognition()['stopped'], isTrue);
      result(['hello Motchi', 'find a movie'], finalResult: true);
      recognition().callMethod('onend', [js.JsObject.jsify({})]);
      expect(await pending, 'hello Motchi find a movie');
    },
  );

  test('cancel discards partial speech and aborts the microphone', () async {
    final pending = bridge.recognizeOnce();
    result(['discard this'], finalResult: false);
    bridge.cancelRecognition();
    expect(await pending, isNull);
    expect(recognition()['aborted'], isTrue);
  });

  test('empty session returns no text', () async {
    final pending = bridge.recognizeOnce();
    recognition().callMethod('onend', [js.JsObject.jsify({})]);
    expect(await pending, isNull);
  });

  test('permission errors are not mistaken for empty speech', () async {
    final pending = bridge.recognizeOnce();
    final assertion = expectLater(pending, throwsStateError);
    recognition().callMethod('onerror', [
      js.JsObject.jsify({'error': 'not-allowed'}),
    ]);
    await assertion;
  });
}
