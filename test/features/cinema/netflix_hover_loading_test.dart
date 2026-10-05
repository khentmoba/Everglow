import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:everglow/features/cinema/data/models/media_item.dart';
import 'package:everglow/features/cinema/presentation/widgets/netflix/netflix_hover_preview.dart';
import 'package:everglow/shared/widgets/everglow/everglow_skeleton.dart';

void main() {
  testWidgets('hover shows shimmer while details load, then fallback', (
    tester,
  ) async {
    final item = MediaItem(
      id: 'loading-shimmer-1',
      tmdbId: 999999999,
      title: 'Loading Test Movie',
      mediaType: 'movie',
      posterPath: '',
      backdropPath: '',
      year: '',
      status: 'to-watch',
      addedAt: DateTime(2026, 1, 1),
      source: 'tmdb',
      synopsis: '',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: NetflixHoverPreview(item: item, width: 324)),
      ),
    );

    // Immediately after build the TMDB fetch is still in flight, so the
    // popover must show animated shimmer — not the static fallback copy.
    // No extra pump here: the failed test-env fetch resolves on the next
    // pump, which would close the loading window.
    expect(find.byType(EverglowLoadingBars), findsOneWidget);
    expect(find.byType(EverglowSkeleton), findsWidgets);
    expect(find.textContaining('Tap for details'), findsNothing);

    // Once the fetch resolves ({} in tests — no Firebase), the fallback
    // copy replaces the shimmer.
    await tester.pumpAndSettle(const Duration(seconds: 5));
    expect(find.byType(EverglowLoadingBars), findsNothing);
    expect(find.textContaining('Tap for details'), findsOneWidget);
  });

  testWidgets('hover with full payload never shows loading shimmer', (
    tester,
  ) async {
    final item = MediaItem(
      id: 'full-payload-1',
      tmdbId: 1001,
      title: 'Full Payload Movie',
      mediaType: 'movie',
      posterPath: '',
      backdropPath: '',
      year: '2026',
      status: 'to-watch',
      addedAt: DateTime(2026, 1, 1),
      source: 'tmdb',
      synopsis: 'A complete synopsis from the row payload.',
      genres: const ['Action', 'Drama'],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: NetflixHoverPreview(item: item, width: 324)),
      ),
    );
    await tester.pump();

    expect(find.byType(EverglowLoadingBars), findsNothing);
    expect(find.textContaining('complete synopsis'), findsOneWidget);
  });
}
