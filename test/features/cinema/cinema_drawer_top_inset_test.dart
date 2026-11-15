import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:everglow/features/cinema/presentation/widgets/episode_drawer_sections/cinema/cinema_hero.dart';
import 'package:everglow/features/cinema/presentation/widgets/episode_drawer_sections/trailer_section.dart';

Future<Offset> _closeIconOffset(
  WidgetTester tester,
  Widget hero, {
  required EdgeInsets padding,
}) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: const Size(390, 844),
          padding: padding,
        ),
        child: Scaffold(body: hero),
      ),
    ),
  );
  await tester.pump();
  final finder = find.byIcon(Icons.close_rounded);
  expect(finder, findsOneWidget);
  return tester.getTopLeft(finder);
}

CinemaHero _cinemaHero() => CinemaHero(
  backdropUrl: '',
  posterUrl: '',
  isLoadingTrailer: false,
  isPlayingTrailer: false,
  isMobile: true,
  trailerUserInitiated: false,
  isWide: false,
  year: '2016',
  rating: '7.5',
  ratingFraction: 0.75,
  runtime: 107,
  title: 'Moana',
  isDetailsLoading: false,
  onToggleTrailer: () {},
  onCloseTrailer: () {},
  onClose: () {},
);

TrailerSection _trailerSection() => TrailerSection(
  backdropUrl: '',
  isLoadingTrailer: false,
  isPlayingTrailer: false,
  isMobile: true,
  year: '2016',
  rating: '7.5',
  ratingFraction: 0.75,
  runtime: 107,
  title: 'Moana',
  isDetailsLoading: false,
  onToggleTrailer: () {},
  onCloseTrailer: () {},
  onClose: () {},
);

void main() {
  testWidgets('cinema hero close X clears a 47px iPhone notch', (
    WidgetTester tester,
  ) async {
    final offset = await _closeIconOffset(
      tester,
      _cinemaHero(),
      padding: const EdgeInsets.only(top: 47),
    );
    expect(offset.dy, greaterThanOrEqualTo(47));
  });

  testWidgets('cinema hero close X unchanged without an inset', (
    WidgetTester tester,
  ) async {
    final offset = await _closeIconOffset(
      tester,
      _cinemaHero(),
      padding: EdgeInsets.zero,
    );
    expect(offset.dy, closeTo(10, 2));
  });

  testWidgets('classic trailer close X clears a 47px iPhone notch', (
    WidgetTester tester,
  ) async {
    final offset = await _closeIconOffset(
      tester,
      _trailerSection(),
      padding: const EdgeInsets.only(top: 47),
    );
    expect(offset.dy, greaterThanOrEqualTo(47));
  });

  testWidgets('classic trailer close X unchanged without an inset', (
    WidgetTester tester,
  ) async {
    final offset = await _closeIconOffset(
      tester,
      _trailerSection(),
      padding: EdgeInsets.zero,
    );
    expect(offset.dy, closeTo(14, 2));
  });
}
