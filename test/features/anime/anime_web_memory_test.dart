@TestOn('browser')
library;

import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web/web.dart' as web;
import 'package:everglow/features/anime/presentation/widgets/animex/animex_player_web.dart';
import 'package:everglow/features/anime/presentation/widgets/animex/animex_spotlight.dart';
import 'package:everglow/features/cinema/presentation/widgets/trailer_player_web.dart';
import 'package:everglow/features/cinema/data/models/media_item.dart';
import 'package:everglow/shared/widgets/everglow/lazy_indexed_stack.dart';

// Counts custom factory registrations (must stay zero) and supplies dummy
// roots so fromTagName callbacks run without loading third parties.
class _Registry extends ui_web.PlatformViewRegistry {
  int customFactories = 0;
  @override
  bool registerViewFactory(
    String type,
    Function factory, {
    bool isVisible = true,
  }) {
    customFactories++;
    return super.registerViewFactory(type, factory, isVisible: isVisible);
  }

  @override
  Object getViewById(int id) => web.HTMLDivElement();
}

web.HTMLIFrameElement _frameOf(WidgetTester tester, Type type) {
  final state = tester.state(find.byType(type)) as dynamic;
  return state.debugIframe as web.HTMLIFrameElement;
}

List<MediaItem> _items() => List.generate(
  5,
  (i) => MediaItem(
    id: 'demo-$i',
    tmdbId: i + 1,
    title: 'Demo anime $i',
    mediaType: 'tv',
    posterPath: '',
    status: 'to-watch',
    addedAt: DateTime(2026),
    trailerYoutubeId: 'demoTrailer$i',
  ),
);

void main() {
  late _Registry registry;
  setUp(() {
    registry = _Registry();
    ui_web.debugOverridePlatformViewRegistry(registry);
  });
  tearDown(() => ui_web.debugOverridePlatformViewRegistry(null));

  testWidgets(
    'episode changes release old frames without registering factories',
    (tester) async {
      for (var i = 0; i < 6; i++) {
        await tester.pumpWidget(
          MaterialApp(
            home: AnimeXPlayerFrame(
              key: ValueKey(i),
              url: 'about:blank#demo-episode-$i',
            ),
          ),
        );
        final frame = _frameOf(tester, AnimeXPlayerFrame);
        expect(frame.src, contains('demo-episode-$i'));
        await tester.pumpWidget(const SizedBox.shrink());
        expect(frame.src, 'about:blank');
        expect(frame.parentNode, isNull);
      }
      expect(registry.customFactories, 0);
    },
  );

  testWidgets('Watch Now stays paused past the old carousel deadline', (
    tester,
  ) async {
    var watching = false;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => Stack(
            children: [
              AnimeXSpotlight(
                items: _items(),
                onWatch: (_) => setState(() => watching = true),
              ),
              if (watching)
                const Positioned.fill(child: ColoredBox(color: Colors.black)),
            ],
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 700));
    await tester.tap(find.text('Watch Now'));
    await tester.pump();
    expect(watching, isTrue);
    await tester.pump(const Duration(seconds: 30));
    final trailer = tester.widget<TrailerPlayer>(find.byType(TrailerPlayer));
    expect(trailer.playing, isFalse);
    expect(trailer.videoKey, 'demoTrailer0');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('covering home releases its trailer and stops its carousel', (
    tester,
  ) async {
    Widget build(bool active) => MaterialApp(
      home: LazyIndexedStack(
        index: 0,
        active: active,
        children: [AnimeXSpotlight(items: _items())],
      ),
    );
    await tester.pumpWidget(build(true));
    final oldFrame = _frameOf(tester, TrailerPlayer);
    expect(find.byType(TrailerPlayer), findsOneWidget);
    await tester.pumpWidget(build(false));
    await tester.pump(const Duration(seconds: 60));
    expect(find.byType(TrailerPlayer, skipOffstage: false), findsNothing);
    expect(oldFrame.src, 'about:blank');
    expect(find.text('Demo anime 0'), findsOneWidget);
    await tester.pumpWidget(build(true));
    expect(find.byType(TrailerPlayer), findsOneWidget);
    expect(registry.customFactories, 0);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'shared cinema trailers release hidden media and resume on return',
    (tester) async {
      Widget build(bool active) => MaterialApp(
        home: TickerMode(
          enabled: active,
          child: const TrailerPlayer(videoKey: 'demo-trailer'),
        ),
      );
      await tester.pumpWidget(build(true));
      final frame = _frameOf(tester, TrailerPlayer);
      await tester.pumpWidget(build(false));
      expect(frame.src, 'about:blank');
      expect(find.byType(HtmlElementView), findsNothing);
      await tester.pumpWidget(build(true));
      expect(frame.src, contains('/embed/demo-trailer'));
      expect(find.byType(HtmlElementView), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(frame.src, 'about:blank');
      expect(frame.parentNode, isNull);
      expect(registry.customFactories, 0);
    },
  );
}
