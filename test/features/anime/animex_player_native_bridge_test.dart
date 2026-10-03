@TestOn('vm')
library;

import 'dart:async';

import 'package:everglow/features/anime/presentation/widgets/animex/animex_player_native.dart';
import 'package:everglow/features/anime/presentation/widgets/animex/animex_videasy_progress.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

class _Controller extends PlatformWebViewController {
  _Controller(super.params) : super.implementation();
  final requests = <LoadRequestParams>[];
  final scripts = <String>[];
  final channels = <String, JavaScriptChannelParams>{};
  @override
  Future<void> setJavaScriptMode(JavaScriptMode mode) async {}
  @override
  Future<void> setBackgroundColor(Color color) async {}
  @override
  Future<void> setPlatformNavigationDelegate(
    PlatformNavigationDelegate handler,
  ) async {}
  @override
  Future<void> loadRequest(LoadRequestParams params) async =>
      requests.add(params);
  @override
  Future<void> addJavaScriptChannel(JavaScriptChannelParams params) async {
    channels[params.name] = params;
  }

  @override
  Future<void> runJavaScript(String javaScript) async =>
      scripts.add(javaScript);
}

class _View extends PlatformWebViewWidget {
  _View(super.params) : super.implementation();
  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}

class _Delegate extends PlatformNavigationDelegate {
  _Delegate(super.params) : super.implementation();
  late void Function(String) finished;
  late void Function(WebResourceError) error;
  late FutureOr<NavigationDecision> Function(NavigationRequest) navigate;
  @override
  Future<void> setOnPageFinished(void Function(String) onPageFinished) async {
    finished = onPageFinished;
  }

  @override
  Future<void> setOnWebResourceError(
    void Function(WebResourceError) onError,
  ) async {
    error = onError;
  }

  @override
  Future<void> setOnNavigationRequest(
    FutureOr<NavigationDecision> Function(NavigationRequest) onRequest,
  ) async {
    navigate = onRequest;
  }
}

class _Platform extends WebViewPlatform {
  final controllers = <_Controller>[];
  final delegates = <_Delegate>[];
  @override
  PlatformWebViewController createPlatformWebViewController(
    PlatformWebViewControllerCreationParams params,
  ) {
    final controller = _Controller(params);
    controllers.add(controller);
    return controller;
  }

  @override
  PlatformWebViewWidget createPlatformWebViewWidget(
    PlatformWebViewWidgetCreationParams params,
  ) => _View(params);
  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(
    PlatformNavigationDelegateCreationParams params,
  ) {
    final delegate = _Delegate(params);
    delegates.add(delegate);
    return delegate;
  }
}

void main() {
  const url = '$animeXProxyOrigin/proxyAnime?source=megavid&ep=3&start=20';
  late _Platform platform;
  setUp(() {
    platform = _Platform();
    WebViewPlatform.instance = platform;
  });

  testWidgets('native queues seek, then changes position without reloading', (
    tester,
  ) async {
    Widget player(int? seconds, {int request = 0}) => MaterialApp(
      home: AnimeXPlayerFrame(
        url: url,
        seekSeconds: seconds,
        seekRequest: request,
      ),
    );
    await tester.pumpWidget(player(20));
    await tester.pumpWidget(player(35));
    await tester.pump();
    final controller = platform.controllers.single;
    expect(controller.scripts, isEmpty);
    expect(controller.requests.single.uri.toString(), url);
    expect(
      controller.requests.single.headers['Referer'],
      'https://everglow-1c6db.web.app',
    );
    platform.delegates.single.finished(url);
    await tester.pump();
    expect(controller.scripts.single, contains('seconds:35'));
    expect(controller.scripts.single, contains(animeXProxyOrigin));
    await tester.pumpWidget(player(75));
    expect(controller.scripts.last, contains('seconds:75'));
    expect(controller.scripts.length, 2);
    expect(controller.requests.length, 1);
    expect(platform.controllers.length, 1);
    await tester.pumpWidget(player(75));
    await tester.pumpWidget(player(-1));
    await tester.pumpWidget(player(null));
    expect(controller.scripts.length, 2);
    await tester.pumpWidget(player(75, request: 1));
    expect(
      controller.scripts.length,
      3,
      reason: 'rewinding and pressing the same Skip action sends another seek',
    );
    expect(controller.requests.length, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('native channel validates progress, blocks hijacks, keeps retry', (
    tester,
  ) async {
    final progress = <VideasyProgress>[];
    var errors = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: AnimeXPlayerFrame(
          url: url,
          onProgress: progress.add,
          onContentError: () => errors++,
        ),
      ),
    );
    await tester.pump();
    final controller = platform.controllers.single;
    final channel = controller.channels['EverglowPlayer']!;
    channel.onMessageReceived(
      const JavaScriptMessage(
        message:
            '{"type":"animex-progress","position":25,"duration":100,"episode":3}',
      ),
    );
    channel.onMessageReceived(
      const JavaScriptMessage(
        message:
            '{"type":"animex-progress","position":"25","duration":100,"episode":3}',
      ),
    );
    channel.onMessageReceived(
      const JavaScriptMessage(
        message:
            '{"type":"animex-progress","position":25,"duration":100,"episode":4}',
      ),
    );
    expect(progress.single.positionSeconds, 25);
    final delegate = platform.delegates.single;
    expect(
      await delegate.navigate(
        const NavigationRequest(url: url, isMainFrame: true),
      ),
      NavigationDecision.navigate,
    );
    expect(
      await delegate.navigate(
        const NavigationRequest(url: 'https://evil.example', isMainFrame: true),
      ),
      NavigationDecision.prevent,
    );
    expect(
      await delegate.navigate(
        const NavigationRequest(
          url: '$animeXProxyOrigin/proxyCatalog',
          isMainFrame: true,
        ),
      ),
      NavigationDecision.prevent,
    );
    channel.onMessageReceived(
      const JavaScriptMessage(message: 'animex-content-error'),
    );
    channel.onMessageReceived(
      const JavaScriptMessage(message: 'animex-content-error'),
    );
    await tester.pump();
    expect(errors, 1);
    expect(find.text('This source couldn’t load — try again'), findsOneWidget);
    await tester.tap(find.byType(TextButton));
    await tester.pump();
    expect(
      platform.controllers.length,
      2,
      reason: 'retry replaces a dead WebView',
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
