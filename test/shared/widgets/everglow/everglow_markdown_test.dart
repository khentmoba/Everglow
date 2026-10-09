import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:everglow/core/theme/app_typography.dart';
import 'package:everglow/shared/widgets/everglow/everglow_markdown.dart';

/// Global chat regression: AI answers must never show raw markdown
/// (`**`, `###`, `| tables |`, `---`) in Motchi or Study. Both surfaces
/// render through [EverglowMarkdown], so these lock the shared behavior.
void main() {
  Future<void> pumpMarkdown(WidgetTester tester, String text) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: EverglowMarkdown(text: text)),
      ),
    );
    await tester.pump();
  }

  testWidgets('an orphan empty fence does not create a blank code card', (
    tester,
  ) async {
    await pumpMarkdown(tester, 'Game complete.\n```');
    expect(find.byIcon(Icons.copy_rounded), findsNothing);
    expect(
      find.textContaining('Game complete.', findRichText: true),
      findsWidgets,
    );
  });

  testWidgets('headings render without raw hashes (even without space)', (
    tester,
  ) async {
    await pumpMarkdown(tester, '###Flowcharts\n\n## DETAILS TO REMEMBER');
    expect(find.textContaining('###', findRichText: true), findsNothing);
    expect(find.textContaining('Flowcharts', findRichText: true), findsWidgets);
    expect(find.textContaining('DETAILS', findRichText: true), findsWidgets);
  });

  testWidgets('bold renders without raw stars', (tester) async {
    await pumpMarkdown(
      tester,
      '- **What:** A diagram that shows steps\n\n**Simple Symbols:**',
    );
    expect(find.textContaining('**', findRichText: true), findsNothing);
    expect(find.textContaining('What:', findRichText: true), findsWidgets);
  });

  testWidgets('pipe table renders as a Table, not raw pipes', (tester) async {
    await pumpMarkdown(
      tester,
      '| Symbol | Shape | Purpose |\n|---|---|---|\n| **Terminal** | Rounded | Start / End |',
    );
    expect(find.byType(Table), findsOneWidget);
    expect(find.textContaining('|', findRichText: true), findsNothing);
    expect(find.textContaining('**', findRichText: true), findsNothing);
    expect(find.textContaining('Terminal', findRichText: true), findsWidgets);
  });

  testWidgets('table without leading pipe still renders as a Table', (
    tester,
  ) async {
    await pumpMarkdown(
      tester,
      'Symbol | Shape | Purpose\n---|---|---\nTerminal | Rounded | Start',
    );
    expect(find.byType(Table), findsOneWidget);
  });

  testWidgets('lists and dividers render without raw markers', (tester) async {
    await pumpMarkdown(
      tester,
      '- First point\n- Second point\n\n1. Step one\n2. Step two\n\n---\n\nDone',
    );
    expect(find.byType(EverglowDivider), findsOneWidget);
    expect(find.textContaining('---', findRichText: true), findsNothing);
    expect(
      find.textContaining('First point', findRichText: true),
      findsWidgets,
    );
    expect(find.textContaining('Step one', findRichText: true), findsWidgets);
  });

  testWidgets('consecutive bullets share one grouped card', (tester) async {
    await pumpMarkdown(tester, '- JD Gaming\n- TYLOO\n- Edward Gaming');
    expect(find.byType(EverglowBulletGroup), findsOneWidget);
    expect(find.textContaining('JD Gaming', findRichText: true), findsWidgets);
    expect(find.textContaining('TYLOO', findRichText: true), findsWidgets);
    expect(
      find.textContaining('Edward Gaming', findRichText: true),
      findsWidgets,
    );
  });

  testWidgets('plain chat lists keep formatting without card shells', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EverglowMarkdown(
            text:
                '- **First** point\n- Second point\n\n1. Step one\n2. Step two',
            plain: true,
          ),
        ),
      ),
    );
    expect(
      tester
          .widget<EverglowBulletGroup>(find.byType(EverglowBulletGroup))
          .plain,
      isTrue,
    );
    expect(
      tester
          .widget<EverglowNumberedGroup>(find.byType(EverglowNumberedGroup))
          .plain,
      isTrue,
    );
    for (final type in [EverglowBulletGroup, EverglowNumberedGroup]) {
      expect(
        find
            .descendant(of: find.byType(type), matching: find.byType(Container))
            .evaluate()
            .where(
              (element) =>
                  (element.widget as Container).decoration is BoxDecoration &&
                  ((element.widget as Container).decoration as BoxDecoration)
                          .border !=
                      null,
            ),
        isEmpty,
      );
    }
    expect(find.textContaining('**', findRichText: true), findsNothing);
    expect(find.textContaining('Step two', findRichText: true), findsWidgets);
  });

  testWidgets('plain chat keeps reading type without ornamental markdown', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EverglowMarkdown(
            text:
                '# A little plan\n\n**Tonight:**\n\n- Pick a film\n- Make snacks\n\n💡 Keep it simple',
            plain: true,
            baseStyle: TextStyle(
              fontFamily: AppTypography.reading,
              fontSize: 16,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ),
    );
    final heading = tester.widget<RichText>(
      find.text('A little plan', findRichText: true),
    );
    expect(heading.text.style!.fontFamily, AppTypography.reading);
    expect(heading.text.style!.fontWeight, FontWeight.w600);
    expect(find.textContaining('**', findRichText: true), findsNothing);
    expect(
      find.textContaining('Keep it simple', findRichText: true),
      findsWidgets,
    );
    for (final element
        in find
            .descendant(
              of: find.byType(EverglowMarkdown),
              matching: find.byType(Container),
            )
            .evaluate()) {
      final decoration = (element.widget as Container).decoration;
      if (decoration is BoxDecoration) {
        expect(decoration.gradient, isNull);
        expect(decoration.boxShadow, isNull);
      }
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('numbered steps share one grouped card', (tester) async {
    await pumpMarkdown(tester, '1. Step one\n2. Step two\n3. Step three');
    expect(find.byType(EverglowNumberedGroup), findsOneWidget);
    expect(find.textContaining('Step two', findRichText: true), findsWidgets);
  });

  testWidgets('VCT-style reply: headers hug single list cards', (tester) async {
    await pumpMarkdown(
      tester,
      '**VCT China:**\n- JD Gaming (Stage 2 qualifier)\n- TYLOO (Stage 2 qualifier)\n\n**VCT Pacific:**\n- Nongshim RedForce\n- Paper Rex',
    );
    expect(find.textContaining('**', findRichText: true), findsNothing);
    expect(find.byType(EverglowBulletGroup), findsNWidgets(2));
    expect(find.textContaining('VCT China', findRichText: true), findsWidgets);
    expect(find.textContaining('Paper Rex', findRichText: true), findsWidgets);
  });

  testWidgets('flag-led bullets keep their emoji inside the group', (
    tester,
  ) async {
    await pumpMarkdown(tester, '- 🇨🇳 JD Gaming\n- 🇰🇷 Nongshim RedForce');
    expect(find.byType(EverglowBulletGroup), findsOneWidget);
    expect(find.textContaining('🇨🇳', findRichText: true), findsWidgets);
    expect(
      find.textContaining('Nongshim RedForce', findRichText: true),
      findsWidgets,
    );
  });
}
