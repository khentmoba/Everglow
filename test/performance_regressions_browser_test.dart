@TestOn('browser')
library;

import 'dart:async';
import 'dart:js_interop';
import 'dart:ui' show Rect;
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:web/web.dart' as web;
import 'package:everglow/features/gallery/data/services/upload_image_preparation_web.dart';
import 'package:everglow/features/ai/data/services/study_doc_service.dart';
import 'package:everglow/features/jukebox/data/services/spotify_auth_service.dart';
import 'package:everglow/features/jukebox/data/services/spotify_player_service_web.dart';

@JS('eval')
external JSAny? _eval(String script);

class _Auth extends ChangeNotifier implements SpotifyAuthService {
  int reads = 0;
  @override
  Future<String?> getStoredAccessToken() async {
    reads++;
    return 'synthetic-test-token';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<(int, int)> _dimensions(Uint8List bytes) async {
  final url = web.URL.createObjectURL(web.Blob([bytes.toJS].toJS));
  try {
    final image = web.HTMLImageElement()..src = url;
    await image.decode().toDart;
    return (image.naturalWidth, image.naturalHeight);
  } finally {
    web.URL.revokeObjectURL(url);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'browser prepares proportional full and thumbnail JPEGs asynchronously',
    () async {
      final canvas = web.HTMLCanvasElement()
        ..width = 2400
        ..height = 1200;
      final context = canvas.getContext('2d')! as web.CanvasRenderingContext2D;
      context.fillStyle = '#e5a1bd'.toJS;
      context.fillRect(0, 0, 2400, 1200);
      final source = Completer<web.Blob>();
      canvas.toBlob(
        ((web.Blob? blob) => source.complete(blob!)).toJS,
        'image/jpeg',
      );
      final bytes = (await (await source.future).arrayBuffer().toDart).toDart
          .asUint8List();
      var yielded = false;
      Future<void>.delayed(Duration.zero, () => yielded = true);
      final result = await prepareImages(bytes);
      expect(yielded, isTrue);
      expect(await _dimensions(result.full), (1600, 800));
      expect(await _dimensions(result.thumb!), (400, 200));
      final corrupt = Uint8List.fromList([1, 2, 3]);
      expect((await prepareImages(corrupt)).full, same(corrupt));
      canvas.width = canvas.height = 0;
    },
  );

  test('web PDF extraction yields and retains all pages', () async {
    final pdf = PdfDocument();
    for (var page = 0; page < 4; page++) {
      pdf.pages.add().graphics.drawString(
        'Synthetic page $page',
        PdfStandardFont(PdfFontFamily.helvetica, 12),
        bounds: const Rect.fromLTWH(0, 0, 400, 30),
      );
    }
    final bytes = Uint8List.fromList(await pdf.save());
    pdf.dispose();
    var yielded = false;
    Future<void>.delayed(Duration.zero, () => yielded = true);
    final text = await extractPdfTextAsync(bytes);
    expect(yielded, isTrue);
    for (var page = 0; page < 4; page++) {
      expect(text, contains('Synthetic page $page'));
    }
    await expectLater(
      extractPdfTextAsync(Uint8List.fromList([1])),
      throwsA(isA<StudyDocException>()),
    );
  });

  testWidgets(
    'Spotify shares initialization and releases callbacks and refresh timers',
    (tester) async {
      _eval('''
      window.__testSpotifyCreated = 0;
      window.Spotify = { Player: class {
        constructor(options) { this._options = options; this.listeners = {}; window.__testSpotifyCreated++; }
        addListener(name, fn) { this.listeners[name] = fn; }
        connect() { this.listeners.ready({device_id: 'synthetic-device'}); }
        disconnect() {}
      }};
      window._everglowSpotifyPlayer = null;
    ''');
      final auth = _Auth();
      final player = SpotifyPlayerService(auth);
      final first = player.init();
      final second = player.init();
      expect(identical(first, second), isTrue);
      await tester.pump();
      await first;
      expect((_eval('window.__testSpotifyCreated') as JSNumber).toDartInt, 1);
      expect(player.isConnected, isTrue);
      player.disposePlayer();
      final next = player.init();
      await tester.pump();
      await next;
      expect((_eval('window.__testSpotifyCreated') as JSNumber).toDartInt, 2);
      player.dispose();
      final reads = auth.reads;
      await tester.pump(const Duration(minutes: 51));
      expect(auth.reads, reads);
      _eval(
        "window.dispatchEvent(new CustomEvent('everglow_spotify_ready', {detail:'late'}))",
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      auth.dispose();
      _eval('delete window.Spotify; delete window.__testSpotifyCreated;');
    },
  );
}
