import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:everglow/features/cinema/data/models/media_item.dart';
import 'package:everglow/features/cinema/presentation/widgets/netflix/netflix_hover_preview.dart';
import 'package:everglow/features/cinema/presentation/widgets/netflix/netflix_poster_card.dart';
import 'package:everglow/features/cinema/presentation/widgets/netflix/netflix_row.dart';

MediaItem _item(int i) {
  return MediaItem(
    id: 'm$i',
    tmdbId: 1000 + i,
    title: 'Hover Test Title $i',
    mediaType: 'movie',
    posterPath: '',
    backdropPath: '',
    year: '2026',
    status: 'to-watch',
    addedAt: DateTime(2026, 1, 1),
    source: 'tmdb',
    synopsis: 'A synopsis so the preview skips the details fetch.',
  );
}

void main() {
  testWidgets('hovering a poster shows the preview, leaving closes it', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.black,
          body: Column(
            children: [
              NetflixRow(
                title: 'Trending Now',
                items: List.generate(6, _item),
                onTapItem: (_) {},
              ),
              const Expanded(child: SizedBox.expand()),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: const Offset(1300, 800));
    await tester.pump();
    await gesture.moveTo(
      tester.getCenter(find.byType(NetflixPosterCard).first),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.byType(NetflixHoverPreview),
      findsOneWidget,
      reason: 'hovering a poster for 260ms+ should show the preview',
    );

    await gesture.moveTo(const Offset(1300, 800));
    await tester.pump();

    expect(
      find.byType(NetflixHoverPreview),
      findsNothing,
      reason: 'leaving the preview should dismiss it',
    );

    await gesture.removePointer();
    debugDefaultTargetPlatformOverride = null;
  });
}
