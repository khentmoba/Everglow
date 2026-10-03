@TestOn('browser')
library;

import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:ui_web' as ui_web;

import 'package:everglow/features/anime/presentation/widgets/animex/animex_player_web.dart';
import 'package:everglow/features/anime/presentation/widgets/animex/animex_videasy_progress.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web/web.dart' as web;

// Detached platform roots stop any real provider request. Tests attach a
// blank frame manually, retaining its genuine contentWindow/source identity.
class _Registry extends ui_web.PlatformViewRegistry {
  @override
  Object getViewById(int id) => web.HTMLDivElement();
}

void main() {
  const url = '$animeXProxyOrigin/proxyAnime?source=megavid&ep=3';
  setUp(() => ui_web.debugOverridePlatformViewRegistry(_Registry()));
  tearDown(() => ui_web.debugOverridePlatformViewRegistry(null));

  Future<web.HTMLIFrameElement> frameFor(WidgetTester tester) async {
    final state = tester.state(find.byType(AnimeXPlayerFrame)) as dynamic;
    final frame = state.debugIframe as web.HTMLIFrameElement;
    await tester.runAsync(() async {
      final loaded = Completer<void>();
      frame.addEventListener(
        'load',
        ((web.Event event) => loaded.complete()).toJS,
        web.AddEventListenerOptions(once: true),
      );
      frame.src = 'about:blank';
      web.document.body!.appendChild(frame);
      await loaded.future;
    });
    return frame;
  }

  void message(web.Window? source, String origin, Object data) {
    web.window.dispatchEvent(
      web.MessageEvent(
        'message',
        web.MessageEventInit(
          source: source,
          origin: origin,
          data: data.jsify(),
        ),
      ),
    );
  }

  testWidgets('all event types reject foreign frames even on the same origin', (
    tester,
  ) async {
    final progress = <VideasyProgress>[];
    final episodes = <(int, int)>[];
    var errors = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: AnimeXPlayerFrame(
          url: url,
          onProgress: progress.add,
          onPlayerEpisodeChanged: (s, e) => episodes.add((s, e)),
          onContentError: () => errors++,
        ),
      ),
    );
    final frame = await frameFor(tester);
    final foreign = web.HTMLIFrameElement()..src = 'about:blank';
    web.document.body!.appendChild(foreign);
    addTearDown(() => foreign.remove());
    final events = <Object>[
      {
        'type': 'animex-progress',
        'position': 25,
        'duration': 100,
        'episode': 3,
      },
      {'type': 'cinesrc:nextepisode', 'season': 1, 'episode': 4},
      'animex-content-error',
      {'type': 'everglow-embed-failed'},
    ];
    for (final data in events) {
      message(foreign.contentWindow, animeXProxyOrigin, data);
      message(frame.contentWindow, 'https://evil.example', data);
      message(null, animeXProxyOrigin, data);
    }
    expect(progress, isEmpty);
    expect(episodes, isEmpty);
    expect(errors, 0);
    for (final data in events) {
      message(frame.contentWindow, animeXProxyOrigin, data);
    }
    expect(progress.single.positionSeconds, 25);
    expect(episodes, [(1, 4)]);
    expect(errors, 1, reason: 'content failure is only reported once');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'pending and updated seeks send messages without reloading the frame',
    (tester) async {
      Widget player(int? seconds, {int request = 0}) => MaterialApp(
        home: AnimeXPlayerFrame(
          url: url,
          seekSeconds: seconds,
          seekRequest: request,
        ),
      );
      await tester.pumpWidget(player(20));
      // Property changes before load retain the latest request.
      await tester.pumpWidget(player(35));
      final frame = await frameFor(tester);
      final sent = <Object?>[];
      final targets = <String>[];
      frame.contentWindow!.setProperty(
        'postMessage'.toJS,
        ((JSAny? data, JSString target) {
          sent.add(data?.dartify());
          targets.add(target.toDart);
        }).toJS,
      );
      frame.dispatchEvent(web.Event('load'));
      expect(sent.single, {'type': 'animex-seek', 'seconds': 35});
      await tester.pumpWidget(player(75));
      expect(sent.last, {'type': 'animex-seek', 'seconds': 75});
      expect(sent.length, 2);
      expect(targets, everyElement(animeXProxyOrigin));
      expect(
        frame.src,
        'about:blank',
        reason: 'property update never rewrites src',
      );
      final state = tester.state(find.byType(AnimeXPlayerFrame)) as dynamic;
      expect(state.debugIframe, same(frame));
      await tester.pumpWidget(player(75));
      await tester.pumpWidget(player(-1));
      await tester.pumpWidget(player(null));
      expect(sent.length, 2);
      await tester.pumpWidget(player(75, request: 1));
      expect(
        sent.length,
        3,
        reason: 'the same explicit skip can be used after rewinding',
      );
      expect(frame.src, 'about:blank');
      await tester.pumpWidget(const SizedBox.shrink());
      expect(frame.parentNode, isNull);
    },
  );

  testWidgets('CineSrc does not receive invented seek or progress messages', (
    tester,
  ) async {
    final progress = <VideasyProgress>[];
    Widget player(int seconds) => MaterialApp(
      home: AnimeXPlayerFrame(
        url: 'https://everglow-1c6db.web.app/embed.html?tmdbId=1',
        seekSeconds: seconds,
        onProgress: progress.add,
      ),
    );
    await tester.pumpWidget(player(20));
    final frame = await frameFor(tester);
    final sent = <Object?>[];
    frame.contentWindow!.setProperty(
      'postMessage'.toJS,
      ((JSAny? data, JSString target) => sent.add(data?.dartify())).toJS,
    );
    frame.dispatchEvent(web.Event('load'));
    await tester.pumpWidget(player(50));
    message(frame.contentWindow, 'https://everglow-1c6db.web.app', {
      'type': 'animex-progress',
      'position': 25,
      'duration': 100,
      'episode': 3,
    });
    expect(sent, isEmpty);
    expect(progress, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
