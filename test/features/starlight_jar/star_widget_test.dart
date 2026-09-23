import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:everglow/features/starlight_jar/presentation/widgets/star_widget.dart';
import 'package:everglow/features/starlight_jar/presentation/screens/starlight_jar_widget.dart';
import 'package:everglow/features/starlight_jar/domain/models/star_note.dart';
import 'package:everglow/core/theme/app_colors.dart';

void main() {
  group('StarWidget & drawOrigamiStar', () {
    testWidgets('renders StarWidget without error', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                StarWidget(
                  color: AppColors.auroraGold,
                  position: Offset(50, 50),
                  size: 28,
                  rotation: 0.5,
                  sparkle: 0.8,
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(StarWidget), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(StarWidget),
          matching: find.byType(CustomPaint),
        ),
        findsOneWidget,
      );
    });

    testWidgets(
      'drawOrigamiStar paints without error across various parameters',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CustomPaint(
                size: const Size(200, 200),
                painter: _TestStarPainter(),
              ),
            ),
          ),
        );

        expect(find.byType(CustomPaint), findsWidgets);
      },
    );

    testWidgets('StarlightJarWidget renders 27 preview notes cleanly', (
      tester,
    ) async {
      final fakeNotes = List.generate(
        27,
        (i) => StarNote(
          id: 'preview_star_$i',
          content: 'Gratitude note #$i',
          author: i.isEven ? 'khent' : 'clair',
          timestamp: DateTime.utc(2026, 9, 20),
          category: starCategories[i % starCategories.length],
        ),
      );

      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => Scaffold(
              body: SingleChildScrollView(
                child: StarlightJarWidget(previewNotes: fakeNotes),
              ),
            ),
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));

      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('27 stars'), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);

      // Cleanly dispose widget tree
      await tester.pumpWidget(const SizedBox());
    });
  });
}

class _TestStarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(50, 50);
    drawOrigamiStar(
      canvas,
      color: AppColors.auroraRose,
      size: 24,
      opacity: 0.9,
      glowIntensity: 1.0,
      sparkle: 1.0,
    );
    canvas.restore();

    canvas.save();
    canvas.translate(120, 120);
    drawOrigamiStar(
      canvas,
      color: AppColors.auroraTeal,
      size: 32,
      opacity: 0.7,
      glowIntensity: 0.0,
      sparkle: 0.0,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
