import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:everglow/features/anime/data/models/animex_models.dart';
import 'package:everglow/features/anime/data/services/anilist_service.dart';
import 'package:everglow/features/anime/presentation/widgets/animex/animex_controller.dart';
import 'package:everglow/features/anime/presentation/widgets/animex/animex_search_page.dart';
import 'package:everglow/features/anime/presentation/widgets/animex/animex_grid.dart';
import 'package:everglow/features/cinema/data/models/media_item.dart';

class _Service implements AniListService {
  final requests = <String, Completer<AnimexMediaPage>>{};
  @override
  Future<AnimexMediaPage> fetchAnimexPage({
    String? search,
    String? sort,
    String? status,
    String? season,
    int? seasonYear,
    String? format,
    String? genre,
    int page = 1,
    int perPage = 24,
  }) => (requests[search ?? ''] = Completer<AnimexMediaPage>()).future;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('a late old search cannot replace the newest cards', (
    tester,
  ) async {
    final service = _Service();
    final controller = AnimeXController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnimeXSearchPage(controller: controller, service: service),
        ),
      ),
    );
    Future<void> query(String text) async {
      await tester.enterText(find.byType(TextField), text);
      await tester.pump(const Duration(milliseconds: 451));
    }

    AnimexMediaPage result(String title) => AnimexMediaPage(
      items: [
        MediaItem(
          id: title,
          tmdbId: 1,
          title: title,
          mediaType: 'tv',
          posterPath: '',
          status: '',
          addedAt: DateTime(2026),
        ),
      ],
      scores: const [],
      currentPage: 1,
      hasNextPage: false,
    );
    await query('old');
    await query('new');
    service.requests['new']!.complete(result('New result'));
    await tester.pump();
    service.requests['old']!.complete(result('Old result'));
    await tester.pump();
    expect(
      tester.widget<AnimeXGrid>(find.byType(AnimeXGrid)).items.single.title,
      'New result',
    );
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });
}
