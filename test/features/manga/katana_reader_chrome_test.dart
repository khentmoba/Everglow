import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:everglow/core/services/auth_service.dart';
import 'package:everglow/features/manga/data/models/katana_models.dart';
import 'package:everglow/features/manga/presentation/screens/katana_reader_screen.dart';

/// The chapter page the reader scrapes its page URLs out of.
const _chapterHtml =
    "<html><body><script>var thzq=['https://i1.mangakatana.com/p1.jpg',"
    "'https://i1.mangakatana.com/p2.jpg','https://i1.mangakatana.com/p3.jpg',"
    "'https://i1.mangakatana.com/p4.jpg'];</script></body></html>";

class _PageHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => _FakeHttpClient();
}

class _FakeHttpClient implements HttpClient {
  @override
  bool autoUncompress = true;

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async =>
      _FakeHttpClientRequest();

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeHttpClientRequest implements HttpClientRequest {
  @override
  final HttpHeaders headers = _FakeHttpHeaders();

  @override
  bool followRedirects = true;

  @override
  int maxRedirects = 20;

  @override
  int contentLength = 0;

  @override
  bool persistentConnection = true;

  @override
  Future<HttpClientResponse> close() async => _FakeHttpClientResponse();

  @override
  Future<void> addStream(Stream<List<int>> stream) => stream.drain<void>();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpHeaders implements HttpHeaders {
  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {}

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}

  @override
  void forEach(void Function(String name, List<String> values) action) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpClientResponse extends Stream<List<int>>
    implements HttpClientResponse {
  static final List<int> body = utf8.encode(_chapterHtml);

  @override
  HttpHeaders get headers => _FakeHttpHeaders();

  @override
  int get statusCode => 200;

  @override
  int get contentLength => body.length;

  @override
  bool get isRedirect => false;

  @override
  List<RedirectInfo> get redirects => const [];

  @override
  bool get persistentConnection => true;

  @override
  String get reasonPhrase => 'OK';

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.value(body).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Auth extends ChangeNotifier implements AuthService {
  @override
  String? get currentUser => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// One sampled frame of the reader chrome: where the top bar's back button
/// and the bottom bar's "Next" button sit on screen.
typedef _Sample = ({double topY, double bottomY});

void main() {
  testWidgets('reader chrome slides in from both edges at one speed', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    HttpOverrides.global = _PageHttpOverrides();
    addTearDown(() => HttpOverrides.global = null);

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthService>.value(
        value: _Auth(),
        child: const MaterialApp(
          home: KatanaReaderScreen(
            slug: 'chrome-slide',
            chapterId: 'c1',
            chapters: [
              KatanaChapter(id: 'c1', num: '1', title: 'Chapter 1'),
              KatanaChapter(id: 'c2', num: '2', title: 'Chapter 2'),
            ],
            mangaTitle: 'Chrome Slide',
          ),
        ),
      ),
    );

    // Let the chapter resolve into the webtoon viewer, which is what owns
    // the tap-to-toggle-chrome gesture.
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    final back = find.byTooltip('Back');
    final next = find.text('Next ›');
    expect(back, findsOneWidget, reason: 'reader chrome should be mounted');
    expect(next, findsOneWidget);

    _Sample sample() =>
        (topY: tester.getTopLeft(back).dy, bottomY: tester.getTopLeft(next).dy);

    final hidden = sample();

    await tester.tapAt(const Offset(195, 420));
    // The reader also listens for double-tap zoom, so the single tap only
    // resolves once the double-tap window closes.
    await tester.pump(const Duration(milliseconds: 300));

    final samples = <_Sample>[];
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      samples.add(sample());
    }
    final shown = samples.last;

    // The header starts above the screen and ends below where it started;
    // the footer starts below the screen and ends above where it started.
    expect(hidden.topY, lessThan(0), reason: 'header rests off-screen');
    expect(hidden.bottomY, greaterThan(844), reason: 'footer rests off-screen');
    expect(shown.topY, greaterThan(hidden.topY));
    expect(shown.bottomY, lessThan(hidden.bottomY));

    // Real motion, not a pop: both bars have to be caught part-way in.
    final topSteps = samples.map((s) => s.topY).toSet();
    final bottomSteps = samples.map((s) => s.bottomY).toSet();
    expect(
      topSteps.length,
      greaterThan(4),
      reason: 'header jumped straight to its resting place: $topSteps',
    );
    expect(
      bottomSteps.length,
      greaterThan(4),
      reason: 'footer jumped straight to its resting place: $bottomSteps',
    );

    // Same speed: neither bar may arrive before the other.
    final topArrival = samples.indexWhere((s) => s.topY == shown.topY);
    final bottomArrival = samples.indexWhere((s) => s.bottomY == shown.bottomY);
    expect(topArrival, greaterThanOrEqualTo(0));
    expect(bottomArrival, greaterThanOrEqualTo(0));
    expect(
      (topArrival - bottomArrival).abs(),
      lessThanOrEqualTo(1),
      reason:
          'header arrived on frame $topArrival, footer on frame '
          '$bottomArrival — they must move together',
    );
  });
}
