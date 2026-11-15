import 'dart:async';

import 'package:everglow/features/anime/data/models/animex_models.dart';
import 'package:everglow/features/anime/presentation/widgets/animex/animex_controller.dart';
import 'package:everglow/features/anime/presentation/widgets/animex/animex_home_page.dart';
import 'package:everglow/features/cinema/data/models/media_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
    'AnimeXHomePage defers flushing arriving rows during vertical scroll until scroll ends',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final pending = {
        for (final id in [
          'trending',
          'airing',
          'seasonal',
          'popular',
          'completed',
        ])
          id: Completer<AnimexMediaPage>(),
      };

      AnimexMediaPage page(List<MediaItem> items) => AnimexMediaPage(
        items: items,
        scores: const [],
        currentPage: 1,
        hasNextPage: false,
      );

      MediaItem item(int id, String title) => MediaItem(
        id: '$id',
        tmdbId: id,
        title: title,
        mediaType: 'tv',
        posterPath: '',
        status: '',
        isAnime: true,
        addedAt: DateTime(2026),
      );

      final controller = AnimeXController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimeXHomePage(
              controller: controller,
              loadRow: (id) => pending[id]!.future,
            ),
          ),
        ),
      );
      await tester.pump();
      pending['trending']!.complete(page([item(1, 'Immediate Hero Anime')]));
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(find.text('Immediate Hero Anime'), findsWidgets);

      final listCenter = tester.getCenter(find.byType(ListView).first);
      final gesture = await tester.startGesture(listCenter);
      await gesture.moveBy(const Offset(0, -180));
      await tester.pump();

      pending['airing']!.complete(page([item(2, 'Deferred Airing Anime')]));
      await tester.pump(const Duration(milliseconds: 30));
      expect(find.textContaining('Deferred Airing Anime'), findsNothing);

      await gesture.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.textContaining('Deferred Airing Anime'), findsWidgets);

      for (final id in ['seasonal', 'popular', 'completed']) {
        pending[id]!.complete(page(const []));
      }
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    },
  );
}
