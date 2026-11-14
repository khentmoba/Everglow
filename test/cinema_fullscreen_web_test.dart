@TestOn('browser')
library;

import 'dart:ui_web' as ui_web;

import 'package:everglow/core/agent/agent_mode.dart';
import 'package:everglow/core/services/auth_service.dart';
import 'package:everglow/features/cinema/presentation/screens/video_player_screen_web.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web/web.dart' as web;

// Keep the embedded provider detached: the test uses only the demo catalogue.
class _Registry extends ui_web.PlatformViewRegistry {
  @override
  Object getViewById(int id) => web.HTMLDivElement();
}

class _DemoAuth extends ChangeNotifier implements AuthService {
  @override
  String? get currentUser => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

web.HTMLButtonElement? get _exitButton =>
    web.document.querySelector('button[aria-label="Exit theater"]')
        as web.HTMLButtonElement?;

Future<void> _pumpPlayer(WidgetTester tester, Size size) async {
  await _size(tester, size);
  addTearDown(() async {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    await tester.binding.setSurfaceSize(null);
  });
  await tester.pumpWidget(
    ChangeNotifierProvider<AuthService>.value(
      value: _DemoAuth(),
      child: const MaterialApp(
        home: VideoPlayerScreen(
          tmdbId: 900004,
          mediaType: 'tv',
          title: 'The Midnight Library',
          season: 1,
          episode: 1,
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _size(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  await tester.binding.setSurfaceSize(size);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AgentMode.isActive.value = true;
    AgentMode.useDemoData.value = true;
    ui_web.debugOverridePlatformViewRegistry(_Registry());
  });
  tearDown(() {
    AgentMode.isActive.value = false;
    ui_web.debugOverridePlatformViewRegistry(null);
  });

  for (final platform in [
    TargetPlatform.windows,
    TargetPlatform.macOS,
    TargetPlatform.linux,
  ]) {
    testWidgets('short $platform window keeps episodes outside theater', (
      tester,
    ) async {
      await _size(tester, const Size(1280, 550));
      addTearDown(() async {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        await tester.binding.setSurfaceSize(null);
      });
      await tester.pumpWidget(
        ChangeNotifierProvider<AuthService>.value(
          value: _DemoAuth(),
          child: const MaterialApp(
            home: VideoPlayerScreen(
              tmdbId: 900004,
              mediaType: 'tv',
              title: 'The Midnight Library',
              season: 1,
              episode: 1,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(_exitButton, isNull, reason: 'desktop must not open theater');
      expect(find.text('Episodes').hitTestable(), findsOneWidget);

      await tester.tap(find.byTooltip('Theater mode'));
      await tester.pump();
      expect(_exitButton, isNotNull, reason: 'manual theater is available');
      _exitButton!.click();
      await tester.pump();
      await tester.pump();
      expect(_exitButton, isNull);
      await tester.tap(find.text('Episodes'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.ensureVisible(find.text('Episode 2'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Episode 2'));
      await tester.pump();
      await tester.pump();
      expect(find.text('S1 E2'), findsOneWidget);
      expect(_exitButton, isNull);

      await _size(tester, const Size(1366, 768));
      await tester.pump();
      await _size(tester, const Size(1280, 550));
      await tester.pump();
      await tester.pump();
      expect(_exitButton, isNull, reason: 'resizing is not phone rotation');
      await tester.pumpWidget(const SizedBox.shrink());
    }, variant: TargetPlatformVariant({platform}));
  }

  testWidgets('exiting landscape theater leaves the episode selector usable', (
    tester,
  ) async {
    await _size(tester, const Size(932, 430));
    addTearDown(() async {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      await tester.binding.setSurfaceSize(null);
    });
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthService>.value(
        value: _DemoAuth(),
        child: const MaterialApp(
          home: VideoPlayerScreen(
            tmdbId: 900004,
            mediaType: 'tv',
            title: 'The Midnight Library',
            season: 1,
            episode: 1,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(_exitButton, isNotNull, reason: 'landscape opens theater');

    _exitButton!.click();
    await tester.pump();
    await tester.pump();
    expect(_exitButton, isNull, reason: 'manual exit must stay exited');
    expect(find.text('Episodes'), findsOneWidget);

    await tester.tap(find.text('Episodes'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.ensureVisible(find.text('Episode 2'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Episode 2').hitTestable(), findsOneWidget);
    await tester.tap(find.text('Episode 2'));
    await tester.pump();
    await tester.pump();
    expect(find.text('S1 E2'), findsOneWidget);
    expect(_exitButton, isNull, reason: 'changing episodes must not reopen it');
    expect(find.text('Episodes'), findsOneWidget);

    await _size(tester, const Size(430, 932));
    await tester.pump();
    await _size(tester, const Size(932, 430));
    await tester.pump();
    await tester.pump();
    expect(_exitButton, isNotNull, reason: 'a new rotation can open theater');
    await _size(tester, const Size(430, 932));
    await tester.pump();
    await tester.pump();
    expect(
      _exitButton,
      isNull,
      reason: 'rotating back closes automatic theater',
    );

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'the app leaves player keys to the browser on the default embed',
    (tester) async {
      await _pumpPlayer(tester, const Size(1280, 720));

      final seek = web.KeyboardEvent(
        'keydown',
        web.KeyboardEventInit(
          key: 'ArrowRight',
          bubbles: true,
          cancelable: true,
        ),
      );
      web.document.dispatchEvent(seek);
      expect(
        seek.defaultPrevented,
        isFalse,
        reason:
            'the default provider is CineSrc, not our own HLS player, so '
            'the browser keeps the key',
      );

      final unrelated = web.KeyboardEvent(
        'keydown',
        web.KeyboardEventInit(key: 'q', bubbles: true, cancelable: true),
      );
      web.document.dispatchEvent(unrelated);
      expect(
        unrelated.defaultPrevented,
        isFalse,
        reason: 'unrelated keys were never forwarded',
      );

      await tester.pumpWidget(const SizedBox.shrink());
    },
    variant: const TargetPlatformVariant({TargetPlatform.windows}),
  );

  test(
    'mounting the embed keeps the element, not its string form',
    () {
      final host = web.HTMLDivElement();
      final iframe = web.HTMLIFrameElement();

      mountPlayerNode(host, iframe);

      // `replaceChildren` takes one node in package:web. A JS array argument
      // stringifies the element into "[object HTMLIFrameElement]", so no embed
      // ever loads and every server times out into the error card.
      expect(host.children.length, 1, reason: 'the host holds one child');
      expect(
        host.children.item(0)?.tagName,
        'IFRAME',
        reason: 'the child is the iframe element itself',
      );
      expect(
        host.textContent,
        isNot(contains('[object')),
        reason: 'the element was never stringified into text',
      );
    },
  );
}
