import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:everglow/shared/widgets/everglow/everglow_markdown.dart';

/// Global chat regression: AI answers must never show raw markdown
/// (`**`, `###`, `| tables |`, `---`) in Mochi or Study. Both surfaces
/// render through [EverglowMarkdown], so these lock the shared behavior.
void main() {
  Future<void> pumpMarkdown(WidgetTester tester, String text) async {
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: EverglowMarkdown(text: text))),
    );
    await tester.pump();
  }

  testWidgets('headings render without raw hashes (even without space)', (
    tester,
  ) async {
    await pumpMarkdown(tester, '###Flowcharts\n\n## DETAILS TO REMEMBER');
    expect(
      find.textContaining('###', findRichText: true),
      findsNothing,
    );
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
    expect(find.byType(Divider), findsOneWidget);
    expect(find.textContaining('---', findRichText: true), findsNothing);
    expect(find.textContaining('First point', findRichText: true), findsWidgets);
    expect(find.textContaining('Step one', findRichText: true), findsWidgets);
  });
}
