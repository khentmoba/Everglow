import 'package:everglow/core/theme/app_theme.dart';
import 'package:everglow/core/theme/app_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('inline and token text inherit the bundled emoji fallback', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.gamifiedTheme,
        home: const Scaffold(
          body: Column(
            children: [
              Text('Mood 💖'),
              Text('Garden 🌱', style: AppTypography.cormorantBold),
              Text('Starlight ✦ ♡', style: AppTypography.outfitWhite),
              Text.rich(
                TextSpan(
                  text: 'Tonight ',
                  children: [TextSpan(text: '🎬')],
                ),
                style: AppTypography.outfitWhite,
              ),
            ],
          ),
        ),
      ),
    );

    for (final copy in [
      'Mood 💖',
      'Garden 🌱',
      'Starlight ✦ ♡',
      'Tonight 🎬',
    ]) {
      final rich = tester.widget<RichText>(
        find.byWidgetPredicate(
          (widget) => widget is RichText && widget.text.toPlainText() == copy,
        ),
      );
      expect(
        rich.text.style!.fontFamilyFallback,
        containsAll(['Everglow Emoji', 'Everglow Symbols']),
      );
    }
    // The emoji fallback must not replace the app's text fonts.
    expect(AppTypography.cormorantBold.fontFamily, AppTypography.display);
    expect(AppTypography.outfitWhite.fontFamily, AppTypography.body);
  });
}
