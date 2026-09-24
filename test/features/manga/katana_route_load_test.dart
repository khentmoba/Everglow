import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:everglow/core/services/auth_service.dart';
import 'package:everglow/features/manga/presentation/screens/katana_home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _CountingHttpOverrides extends HttpOverrides {
  int requests = 0;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return _FakeHttpClient(this);
  }
}

class _FakeHttpClient implements HttpClient {
  _FakeHttpClient(this.overrides);

  final _CountingHttpOverrides overrides;

  @override
  bool autoUncompress = true;

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    overrides.requests++;
    return _FakeHttpClientRequest();
  }

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
  static final body = utf8.encode('<html><body></body></html>');

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

class _FakeAuthService extends ChangeNotifier implements AuthService {
  @override
  String? get currentUser => null;

  @override
  bool get isCoupleUser => false;

  @override
  String? get partnerUsername => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  testWidgets('standalone MangaCelestia home fetches once', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final overrides = _CountingHttpOverrides();
    HttpOverrides.global = overrides;
    addTearDown(() => HttpOverrides.global = null);

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthService>.value(
        value: _FakeAuthService(),
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(0.5)),
            child: child!,
          ),
          home: const KatanaHomeScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));

    expect(overrides.requests, 1);
  });
}
