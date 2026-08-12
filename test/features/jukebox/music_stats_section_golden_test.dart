import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:everglow/features/jukebox/presentation/providers/music_stats_provider.dart';
import 'package:everglow/features/jukebox/presentation/widgets/music_stats_section.dart';

/// Renders [MusicStatsSection] with canned Last.fm responses and captures a
/// golden so the typography/layout can be reviewed visually. Uses a fake
/// [HttpOverrides] because widget tests block real network access.
void main() {
  testWidgets('MusicStatsSection renders the leaderboard and recent list',
      (tester) async {
    HttpOverrides.global = _FakeHttpOverrides();

    tester.view.physicalSize = const Size(560, 1320);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.runAsync(() async {
      _imageBytes = await _solidPng(const Color(0xFF8A5CD6));
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            backgroundColor: const Color(0xFF1A1A2E),
            body: SingleChildScrollView(
              child: SizedBox(
                width: 520,
                child: ChangeNotifierProvider(
                  create: (_) => MusicStatsProvider(),
                  child: const MusicStatsSection(),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 600));
      await tester.pump();
    });

    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MusicStatsSection),
      matchesGoldenFile('goldens/music_stats_section.png'),
    );

    // Dispose the provider so its polling timers don't leak.
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

class _FakeHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return _FakeHttpClient();
  }
}

class _FakeHttpClient implements HttpClient {
  @override
  bool autoUncompress = true;
  @override
  Duration? connectionTimeout;
  @override
  Duration idleTimeout = const Duration(seconds: 15);
  @override
  int? maxConnectionsPerHost;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    return _FakeHttpClientRequest(url);
  }

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    return _FakeHttpClientRequest(url);
  }

  @override
  void close({bool force = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnsupportedError(
      'Unsupported HttpClient member: ${invocation.memberName}',
    );
  }
}

class _FakeHttpClientRequest implements HttpClientRequest {
  final Uri _url;
  final _FakeHeaders _headers = _FakeHeaders();

  _FakeHttpClientRequest(this._url);

  @override
  bool followRedirects = true;
  @override
  int maxRedirects = 5;
  @override
  bool persistentConnection = true;
  @override
  int contentLength = 0;

  @override
  HttpHeaders get headers => _headers;
  @override
  String get method => 'GET';
  @override
  Uri get uri => _url;

  @override
  Future<HttpClientResponse> close() async {
    final bytes = _responseFor(_url);
    return _FakeHttpClientResponse(bytes, isImage: _isImageUrl(_url));
  }

  @override
  Future<void> addStream(Stream<List<int>> stream) async {
    await stream.drain<void>();
  }

  @override
  void add(List<int> data) {}

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnsupportedError(
      'Unsupported HttpClientRequest member: ${invocation.memberName}',
    );
  }
}

class _FakeHttpClientResponse implements HttpClientResponse {
  final Uint8List _bytes;
  final bool isImage;

  _FakeHttpClientResponse(this._bytes, {required this.isImage});

  @override
  int get statusCode => 200;
  @override
  int get contentLength => _bytes.length;
  @override
  bool get isRedirect => false;
  @override
  bool get persistentConnection => true;
  @override
  String get reasonPhrase => 'OK';
  @override
  List<RedirectInfo> get redirects => const [];
  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  HttpHeaders get headers {
    final headers = _FakeHeaders();
    headers.set(
      HttpHeaders.contentTypeHeader,
      isImage ? 'image/png' : 'application/json',
    );
    return headers;
  }

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.fromIterable([_bytes]).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  Stream<S> transform<S>(StreamTransformer<List<int>, S> streamTransformer) {
    return Stream<List<int>>.fromIterable([_bytes])
        .transform(streamTransformer);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnsupportedError(
      'Unsupported HttpClientResponse member: ${invocation.memberName}',
    );
  }
}

class _FakeHeaders implements HttpHeaders {
  final Map<String, List<String>> _values = {};

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {
    _values[name.toLowerCase()] = [value.toString()];
  }

  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {
    _values.putIfAbsent(name.toLowerCase(), () => <String>[]).add(value.toString());
  }

  @override
  String? value(String name) {
    final values = _values[name.toLowerCase()];
    return values == null || values.isEmpty ? null : values.join(', ');
  }

  @override
  void forEach(void Function(String name, List<String> values) action) {
    _values.forEach(action);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnsupportedError(
      'Unsupported HttpHeaders member: ${invocation.memberName}',
    );
  }
}

bool _isImageUrl(Uri url) {
  return url.toString().contains('img.example') ||
      url.toString().contains('lastfm-img');
}

Uint8List? _imageBytes;

Uint8List _responseFor(Uri url) {
  final query = url.query;
  if (query.contains('method=user.gettoptracks')) {
    return utf8.encode(jsonEncode(_topTracksJson));
  }
  if (query.contains('method=user.getrecenttracks')) {
    return utf8.encode(jsonEncode(_recentTracksJson));
  }
  if (query.contains('method=track.getinfo')) {
    return utf8.encode(jsonEncode(_getInfoJson(url)));
  }
  if (_isImageUrl(url)) {
    return _imageBytes ?? Uint8List(0);
  }
  return utf8.encode('{}');
}

Future<Uint8List> _solidPng(Color color) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, 8, 8),
    Paint()..color = color,
  );
  final image = await recorder.endRecording().toImage(8, 8);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}

Map<String, dynamic> _getInfoJson(Uri url) {
  final mbid = Uri.splitQueryString(url.query)['mbid'] ?? '';
  return {
    'track': {
      'album': {
        'title': 'Album',
        'image': [
          {'size': 'small', '#text': 'https://img.example/small.png'},
          {
            'size': 'extralarge',
            '#text': 'https://img.example/$mbid.png',
          },
        ],
      },
    },
  };
}

const _placeholder =
    'https://lastfm-img.freetls.fastly.net/i/u/300x300/'
    '2a96cbd8b46e442fc41c2b86b821562f.png';

final _topTracksJson = {
  'toptracks': {
    'track': [
      for (var i = 0; i < 10; i++)
        {
          'name': 'Top Track ${i + 1}',
          'playcount': '${117 - i * 9}',
          'artist': {'name': 'Artist ${i + 1}'},
          'mbid': 'mbid-${i + 1}',
          'image': [
            {'size': 'small', '#text': _placeholder},
            {'size': 'extralarge', '#text': _placeholder},
          ],
          '@attr': {'rank': '${i + 1}'},
        },
    ],
  },
};

final _recentTracksJson = {
  'recenttracks': {
    'track': [
      {
        'artist': {'#text': 'Mateo'},
        'name': 'Pinipili',
        'album': {'#text': 'Pinipili'},
        'image': [
          {'size': 'small', '#text': _placeholder},
          {'size': 'extralarge', '#text': _placeholder},
        ],
        'date': {
          'uts': '${DateTime.now().millisecondsSinceEpoch ~/ 1000 - 1980}',
        },
      },
      {
        'artist': {'#text': 'Noah Kahan'},
        'name': 'Everywhere, Everything',
        'album': {'#text': 'Stick Season'},
        'image': [
          {'size': 'small', '#text': 'https://img.example/small.png'},
          {
            'size': 'extralarge',
            '#text': 'https://img.example/recent2.png',
          },
        ],
        'date': {
          'uts': '${DateTime.now().millisecondsSinceEpoch ~/ 1000 - 2220}',
        },
      },
      {
        'artist': {'#text': 'BTS'},
        'name': 'Like',
        'album': {'#text': '2 COOL 4 SKOOL'},
        'image': [
          {'size': 'small', '#text': 'https://img.example/small.png'},
          {
            'size': 'extralarge',
            '#text': 'https://img.example/recent3.png',
          },
        ],
        '@attr': {'nowplaying': 'true'},
      },
      {
        'artist': {'#text': 'Seo Ji Won'},
        'name': 'Gather My Tears',
        'album': {'#text': 'Tears'},
        'image': [
          {'size': 'small', '#text': 'https://img.example/small.png'},
          {
            'size': 'extralarge',
            '#text': 'https://img.example/recent4.png',
          },
        ],
        'date': {
          'uts': '${DateTime.now().millisecondsSinceEpoch ~/ 1000 - 3600}',
        },
      },
      {
        'artist': {'#text': 'Kyle Raphael'},
        'name': 'Libu-Libong Buwan',
        'album': {'#text': 'Single'},
        'image': [
          {'size': 'small', '#text': 'https://img.example/small.png'},
          {
            'size': 'extralarge',
            '#text': 'https://img.example/recent5.png',
          },
        ],
        'date': {
          'uts':
              '${DateTime.now().millisecondsSinceEpoch ~/ 1000 - 86400 * 2}',
        },
      },
    ],
  },
};
