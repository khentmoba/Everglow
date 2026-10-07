import 'package:everglow/core/theme/app_motion.dart';
import 'package:everglow/features/anime/presentation/widgets/animex/animex_grid.dart';
import 'package:everglow/features/anime/presentation/widgets/animex/animex_poster_card.dart';
import 'package:everglow/features/anime/presentation/widgets/animex/animex_ticker.dart';
import 'package:everglow/features/cinema/data/models/media_item.dart';
import 'package:everglow/shared/widgets/everglow/everglow_presence_dot.dart';
import 'package:everglow/features/jukebox/presentation/widgets/vinyl_record.dart';
import 'package:everglow/features/jukebox/presentation/widgets/music_card.dart';
import 'package:everglow/features/jukebox/data/models/music_status.dart';
import 'package:everglow/shared/widgets/everglow/animated_emblem.dart';
import 'package:everglow/shared/widgets/everglow/everglow_marquee.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('playing music card does not schedule ambient phone frames', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(414, 896);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MusicCard(
            title: 'Demo music',
            status: MusicStatus(
              username: 'demo',
              trackName: 'Demo song',
              artistName: 'Demo artist',
              albumName: 'Demo album',
              isPlaying: true,
              spotifyUrl: '',
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Demo song'), findsOneWidget);
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
    'phone shelves build lazily, stay still, and swipe to later cards',
    (tester) async {
      tester.view.physicalSize = const Size(414, 896);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final built = <int>{};
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EverglowMarquee(
              children: List.generate(
                100,
                (i) => Builder(
                  builder: (_) {
                    built.add(i);
                    return SizedBox(width: 128, child: Text('Card $i'));
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(built.length, lessThan(12));
      debugPrint('[phone shelf] ${built.length}/100 cards built initially');
      expect(tester.binding.hasScheduledFrame, isFalse);
      final list = find.descendant(
        of: find.byType(EverglowMarquee),
        matching: find.byType(ListView),
      );
      await tester.drag(list, const Offset(-1500, 0));
      await tester.pumpAndSettle();
      expect(built.any((i) => i > 8), isTrue);
      expect(built.length, lessThan(30));
    },
  );

  testWidgets('decorative emblems do not keep phone frames running', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(414, 896);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(child: AnimatedEmblem(icon: Icons.favorite)),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(AppMotion.reduced, isFalse);
    tester.view.physicalSize = const Size(810, 1080);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.binding.hasScheduledFrame, isTrue);
    tester.view.physicalSize = const Size(414, 896);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'saved anime sliver builds a bounded portion of a large library',
    (tester) async {
      tester.view.physicalSize = const Size(414, 896);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final items = List.generate(
        200,
        (i) => MediaItem(
          id: '$i',
          tmdbId: i,
          title: 'Anime $i',
          mediaType: 'tv',
          posterPath: '',
          status: '',
          addedAt: DateTime(2026),
        ),
      );
      final grid = AnimeXGrid(items: items, onTap: (_) {});
      await tester.pumpWidget(
        MaterialApp(home: SingleChildScrollView(child: grid)),
      );
      final eager = find.byType(AnimeXPosterCard).evaluate().length;
      expect(eager, 200);
      await tester.pumpWidget(
        MaterialApp(
          home: CustomScrollView(
            slivers: [AnimeXGrid(sliver: true, items: items, onTap: (_) {})],
          ),
        ),
      );
      final lazy = find.byType(AnimeXPosterCard).evaluate().length;
      expect(lazy, lessThan(16));
      debugPrint('[anime library] $eager -> $lazy mounted cards');
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -1400));
      await tester.pumpAndSettle();
      expect(find.byType(AnimeXPosterCard).evaluate().length, lessThan(16));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('phone ticker, presence and vinyl stay still but remain usable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(414, 896);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Column(
          children: [
            AnimeXTicker(
              items: [
                MediaItem(
                  id: '1',
                  tmdbId: 1,
                  title: 'Demo anime',
                  mediaType: 'tv',
                  posterPath: '',
                  status: '',
                  addedAt: DateTime(2026),
                ),
              ],
            ),
            const EverglowPresenceDot(state: PresenceState.online),
            const VinylRecord(isPlaying: true),
          ],
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Demo anime'), findsOneWidget);
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
