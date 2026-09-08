import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:everglow/features/dashboard/presentation/widgets/shelf_widgets.dart';
import 'package:everglow/shared/widgets/app_network_image.dart';

/// Regression guard for the dashboard "Watched" shelf thumbnails.
///
/// Watched cards render through [ShelfCard]. A card must only fall back to
/// the placeholder tile when the entry genuinely has no poster — relative
/// TMDB paths and absolute URLs must both attempt the network image so a
/// backfilled poster actually shows up instead of the film-strip tile.
Future<void> _pumpCard(WidgetTester tester, String imageUrl) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: ShelfCard(
            accent: ShelfAccent.cinema,
            imageUrl: imageUrl,
            title: 'The Notebook',
            subtitle: 'Movie',
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('Watched card shows placeholder art when no poster is stored', (
    tester,
  ) async {
    await _pumpCard(tester, '');

    expect(find.byType(AppNetworkImage), findsNothing);
    expect(find.byIcon(ShelfAccent.cinema.icon), findsOneWidget);
    expect(find.text('The Notebook'), findsWidgets);
  });

  testWidgets('Watched card attempts poster art for relative TMDB paths', (
    tester,
  ) async {
    await _pumpCard(tester, '/notebook.jpg');

    expect(find.byType(AppNetworkImage), findsOneWidget);
    expect(find.byIcon(ShelfAccent.cinema.icon), findsNothing);
  });

  testWidgets('Watched card attempts poster art for absolute URLs', (
    tester,
  ) async {
    const url = 'https://image.tmdb.org/t/p/w500/notebook.jpg';
    await _pumpCard(tester, url);

    final image = tester.widget<AppNetworkImage>(
      find.byType(AppNetworkImage),
    );
    expect(image.imageUrl, url);
  });
}
