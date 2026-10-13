@TestOn('browser')
library;

// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:js' as js;

import 'package:everglow/features/ai/presentation/widgets/motchi_web_bridge_web.dart';
import 'package:flutter_test/flutter_test.dart';

void fakeVoiceMeter() {
  final originalAudio = js.context['AudioContext'];
  final devices = js.JsObject.fromBrowserObject(
    html.window.navigator.mediaDevices!,
  );
  final originalGetUserMedia = devices['getUserMedia'];
  addTearDown(() {
    js.context['AudioContext'] = originalAudio;
    devices['getUserMedia'] = originalGetUserMedia;
    js.context.callMethod('eval', [
      'window.motchiMeterStream.getTracks().forEach(t => t.stop());',
    ]);
  });
  js.context.callMethod('eval', [
    '''window.motchiMeterSample = 128;
    window.motchiMeterClosed = false;
    window.motchiMeterStream = document.createElement('canvas').captureStream();
    navigator.mediaDevices.getUserMedia = function() {
      return Promise.resolve(window.motchiMeterStream);
    };
    window.AudioContext = function() {
      this.resume = function() { return Promise.resolve(); };
      this.close = function() {
        window.motchiMeterClosed = true;
        return Promise.resolve();
      };
      this.createMediaStreamSource = function() {
        return {connect: function() {}, disconnect: function() {}};
      };
      this.createAnalyser = function() {
        return {getByteTimeDomainData: function(samples) {
          samples.fill(window.motchiMeterSample);
        }};
      };
    };''',
  ]);
}

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
    fakeVoiceMeter();
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

  test('publishes revised interim words without duplicating them', () async {
    final drafts = <String>[];
    final pending = bridge.recognizeOnce(onTranscript: drafts.add);
    expect(recognition()['continuous'], isTrue);
    expect(recognition()['lang'], bridge.speechLanguage);
    result(['pick a cartoon'], finalResult: false);
    result(['pick a cosy movie'], finalResult: true);
    recognition().callMethod('onend', [js.JsObject.jsify({})]);
    expect(drafts, ['pick a cartoon', 'pick a cosy movie']);
    expect(await pending, 'pick a cosy movie');
  });

  test('quiet timeout keeps already recognized words', () async {
    final pending = bridge.recognizeOnce();
    result(['keep these words'], finalResult: true);
    recognition().callMethod('onerror', [
      js.JsObject.jsify({'error': 'no-speech'}),
    ]);
    expect(await pending, 'keep these words');
    expect(recognition()['aborted'], isTrue);
  });

  test(
    'microphone levels respond to audio and stop after cancellation',
    () async {
      final levels = <double>[];
      final pending = bridge.recognizeOnce(onAudioLevel: levels.add);
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(levels, isNotEmpty);
      expect(levels.last, 0);
      js.context['motchiMeterSample'] = 160;
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(levels.last, 1);
      bridge.cancelRecognition();
      expect(await pending, isNull);
      final count = levels.length;
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(levels.length, count);
      expect(js.context['motchiMeterClosed'], isTrue);
      expect(
        js.context.callMethod('eval', [
          'window.motchiMeterStream.getTracks()[0].readyState',
        ]),
        'ended',
      );
    },
  );

  test('a late microphone permission response releases its tracks', () async {
    js.context.callMethod('eval', [
      '''navigator.mediaDevices.getUserMedia = function() {
        return new Promise(resolve => window.motchiResolveMeter = resolve);
      };''',
    ]);
    final pending = bridge.recognizeOnce(onAudioLevel: (_) {});
    bridge.cancelRecognition();
    expect(await pending, isNull);
    js.context.callMethod('eval', [
      'window.motchiResolveMeter(window.motchiMeterStream);',
    ]);
    await Future<void>.delayed(Duration.zero);
    expect(
      js.context.callMethod('eval', [
        'window.motchiMeterStream.getTracks()[0].readyState',
      ]),
      'ended',
    );
  });

  test(
    'Stop preserves words even when the browser never sends onend',
    () async {
      final pending = bridge.recognizeOnce();
      result(['keep my draft'], finalResult: false);
      bridge.stopRecognition();
      expect(await pending, 'keep my draft');
      expect(recognition()['aborted'], isTrue);
    },
  );

  test(
    'Stop releases a late meter stream while recognition is ending',
    () async {
      js.context.callMethod('eval', [
        '''navigator.mediaDevices.getUserMedia = function() {
        return new Promise(resolve => window.motchiResolveMeter = resolve);
      };''',
      ]);
      final pending = bridge.recognizeOnce(onAudioLevel: (_) {});
      bridge.stopRecognition();
      js.context.callMethod('eval', [
        'window.motchiResolveMeter(window.motchiMeterStream);',
      ]);
      await Future<void>.delayed(Duration.zero);
      expect(
        js.context.callMethod('eval', [
          'window.motchiMeterStream.getTracks()[0].readyState',
        ]),
        'ended',
      );
      recognition().callMethod('onend', [js.JsObject.jsify({})]);
      expect(await pending, isNull);
    },
  );

  test('hiding the page stops listening without losing the draft', () async {
    addTearDown(
      () => js.context.callMethod('eval', ['delete document.hidden;']),
    );
    final pending = bridge.recognizeOnce();
    result(['keep my words'], finalResult: true);
    js.context.callMethod('eval', [
      '''Object.defineProperty(document, 'hidden', {configurable: true, value: true});
      document.dispatchEvent(new Event('visibilitychange'));''',
    ]);
    expect(await pending, 'keep my words');
    expect(recognition()['aborted'], isTrue);
  });

  test('meter permission failure does not break transcription', () async {
    js.context.callMethod('eval', [
      "navigator.mediaDevices.getUserMedia = () => Promise.reject(new Error('denied'));",
    ]);
    final pending = bridge.recognizeOnce(onAudioLevel: (_) {});
    await Future<void>.delayed(Duration.zero);
    result(['still listening'], finalResult: true);
    recognition().callMethod('onend', [js.JsObject.jsify({})]);
    expect(await pending, 'still listening');
    expect(js.context['motchiMeterClosed'], isTrue);
  });

  test('empty session returns no text', () async {
    final pending = bridge.recognizeOnce();
    recognition().callMethod('onend', [js.JsObject.jsify({})]);
    expect(await pending, isNull);
  });

  test('reads transcripts from real browser events', () async {
    final pending = bridge.recognizeOnce();
    js.context.callMethod('eval', [
      '''var event = new Event('result');
      event.results = [[{transcript: 'hello from Safari'}]];
      window.motchiTestRecognition.onresult(event);
      window.motchiTestRecognition.onend(new Event('end'));''',
    ]);
    expect(await pending, 'hello from Safari');
  });

  test('browser error events release the microphone', () async {
    final pending = bridge.recognizeOnce();
    final assertion = expectLater(pending, throwsStateError);
    js.context.callMethod('eval', [
      '''var event = new Event('error');
      event.error = 'not-allowed';
      window.motchiTestRecognition.onerror(event);''',
    ]);
    await assertion;
    expect(recognition()['aborted'], isTrue);
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
