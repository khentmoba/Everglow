import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:everglow/features/anime/data/models/animex_models.dart';
import 'package:everglow/features/cinema/data/models/media_item.dart';
import 'package:everglow/features/anime/presentation/widgets/animex/animex_controller.dart';
import 'package:everglow/features/anime/presentation/widgets/animex/animex_home_page.dart';
import 'package:everglow/features/anime/presentation/widgets/animex/animex_poster_row.dart';
import 'package:everglow/features/anime/presentation/widgets/animex/animex_spotlight.dart';

MediaItem _item(String row, int i) => MediaItem(
  id: '$row-$i',
  tmdbId: i,
  title: 'Synthetic $row $i',
  mediaType: 'tv',
  posterPath: '',
  status: '',
  isAnime: true,
  addedAt: DateTime(2026),
);

Finder _vertical() => find.byWidgetPredicate(
  (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
);

Finder _rowScroller(int index) => find
    .descendant(
      of: find.byType(AnimeXPosterRow, skipOffstage: false).at(index),
      matching: find.byType(Scrollable, skipOffstage: false),
    )
    .first;

void main() {
  testWidgets('loaded anime rows keep their place after scrolling away', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(414, 896);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnimeXHomePage(
            controller: AnimeXController(),
            loadRow: (id) async => AnimexMediaPage(
              items: [for (var i = 0; i < 12; i++) _item(id, i)],
              scores: const [],
              currentPage: 1,
              hasNextPage: false,
            ),
          ),
        ),
      ),
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }

    final vertical = tester.state<ScrollableState>(_vertical()).position;
    // Bring the first poster row into view and scroll it sideways.
    vertical.jumpTo(600);
    await tester.pump();
    final rowState = tester.state<ScrollableState>(_rowScroller(0));
    rowState.position.jumpTo(300);
    await tester.pump();

    // Far past the row: a lazy list would have thrown it away by now.
    vertical.jumpTo(vertical.maxScrollExtent);
    await tester.pump();
    expect(
      find.byType(AnimeXSpotlight),
      findsNothing,
      reason: 'the spotlight trailer must still unmount off screen',
    );

    vertical.jumpTo(600);
    await tester.pump();
    final after = tester.state<ScrollableState>(_rowScroller(0));
    expect(identical(after, rowState), isTrue, reason: 'row was rebuilt');
    expect(after.position.pixels, 300);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 30));
  });
}
