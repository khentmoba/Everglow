import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:everglow/features/manga/presentation/widgets/chapter_loading_stage.dart';

Widget _stage({
  bool disableAnimations = false,
  Size viewport = const Size(810, 1080),
  double width = 400,
  double height = 700,
  String? title = 'Chapter 1',
  String? subtitle = 'Solo Leveling',
}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(
        size: viewport,
        disableAnimations: disableAnimations,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF080810),
        body: SizedBox(
          width: width,
          height: height,
          child: ChapterLoadingStage(
            subtitle: subtitle,
            title: title,
            accentColor: const Color(0xFFC2185B),
            surfaceColor: const Color(0xFF14141C),
            pageColor: const Color(0xFF1E1E2A),
            mutedColor: Colors.white54,
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('ChapterLoadingStage', () {
    testWidgets('phone wait stays still; tablet and inactive page resume', (
      tester,
    ) async {
      await tester.pumpWidget(_stage(viewport: const Size(430, 932)));
      await tester.pump(const Duration(seconds: 5));
      expect(find.text('Chapter 1'), findsOneWidget);
      expect(tester.binding.hasScheduledFrame, isFalse);

      await tester.pumpWidget(_stage());
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.binding.hasScheduledFrame, isTrue);

      await tester.pumpWidget(TickerMode(enabled: false, child: _stage()));
      await tester.pump(const Duration(seconds: 5));
      expect(tester.binding.hasScheduledFrame, isFalse);
      await tester.pumpWidget(TickerMode(enabled: true, child: _stage()));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.binding.hasScheduledFrame, isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('shows the chapter and manga names while waiting', (
      tester,
    ) async {
      await tester.pumpWidget(_stage());

      expect(find.text('Chapter 1'), findsOneWidget);
      expect(find.text('Solo Leveling'), findsOneWidget);
    });

    testWidgets('paints pages and cycles the waiting copy', (tester) async {
      await tester.pumpWidget(_stage());

      // The animation is a CustomPainter, not a progress spinner.
      expect(find.byType(CustomPaint), findsWidgets);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text(ChapterLoadingStage.hints.first), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 1400));
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        _hintsOnScreen(tester),
        contains(ChapterLoadingStage.hints[2]),
        reason: 'the copy should advance with the wait',
      );
    });

    testWidgets('works without a title or subtitle', (tester) async {
      await tester.pumpWidget(_stage(title: null, subtitle: null));
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('fits a short phone screen without overflowing', (
      tester,
    ) async {
      await tester.pumpWidget(_stage(width: 360, height: 520));
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
    });

    testWidgets('reduced motion paints a still frame', (tester) async {
      await tester.pumpWidget(_stage(disableAnimations: true));

      expect(find.text('Solo Leveling'), findsOneWidget);

      final before = _hintsOnScreen(tester);
      await tester.pump(const Duration(seconds: 5));

      // Frozen: the same frame and the same line of copy, no drift.
      expect(_hintsOnScreen(tester), before);
      expect(tester.takeException(), isNull);
    });
  });
}

/// Which of the waiting lines are currently on screen (a switching
/// copy briefly shows two at once).
Set<String> _hintsOnScreen(WidgetTester tester) => ChapterLoadingStage.hints
    .where((h) => find.text(h).evaluate().isNotEmpty)
    .toSet();
