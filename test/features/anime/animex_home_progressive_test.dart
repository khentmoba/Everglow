import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:everglow/features/anime/data/models/animex_models.dart';
import 'package:everglow/features/cinema/data/models/media_item.dart';
import 'package:everglow/features/anime/presentation/widgets/animex/animex_controller.dart';
import 'package:everglow/features/anime/presentation/widgets/animex/animex_home_page.dart';
import 'package:everglow/features/anime/presentation/widgets/animex/animex_spotlight.dart';

void main() {
  testWidgets('successful anime hero renders while other feeds are pending', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(414, 896);
    tester.view.devicePixelRatio = 1;
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
    final controller = AnimeXController();
    final item = MediaItem(
      id: 'synthetic',
      tmdbId: 1,
      title: 'Synthetic audit title',
      mediaType: 'tv',
      posterPath: '',
      status: '',
      isAnime: true,
      addedAt: DateTime(2026),
    );
    AnimexMediaPage page(List<MediaItem> items) => AnimexMediaPage(
      items: items,
      scores: const [],
      currentPage: 1,
      hasNextPage: false,
    );
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
    await tester.pump();
    pending['trending']!.complete(page([item]));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(
      tester
          .widget<AnimeXSpotlight>(find.byType(AnimeXSpotlight))
          .items
          .single
          .title,
      item.title,
    );
    for (final id in pending.keys.where((id) => id != 'trending')) {
      pending[id]!.complete(page([]));
    }
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(
      tester
          .widget<AnimeXSpotlight>(find.byType(AnimeXSpotlight))
          .items
          .single
          .title,
      item.title,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });
}
