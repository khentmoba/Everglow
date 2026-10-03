import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:everglow/features/cinema/data/models/media_item.dart';
import 'package:everglow/features/cinema/presentation/widgets/netflix/netflix_colors.dart';
import 'package:everglow/features/cinema/presentation/widgets/netflix/netflix_hover_preview.dart';
import 'package:everglow/features/cinema/presentation/widgets/netflix/netflix_poster_card.dart';
import 'package:everglow/features/cinema/presentation/widgets/netflix/netflix_row.dart';

MediaItem _item([int i = 0]) => MediaItem(
  id: 'demo-$i',
  tmdbId: 91001 + i,
  title: 'Demo Cinema $i with a long title to fit',
  mediaType: 'movie',
  posterPath: '',
  status: 'watching',
  addedAt: DateTime(2026),
  synopsis: 'A demo synopsis for layout and actions.',
);

Finder get _options =>
    find.widgetWithIcon(IconButton, Icons.more_horiz_rounded);

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  double width = 390,
  double textScale = 1,
}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: Align(alignment: Alignment.topLeft, child: child),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _openOptions(WidgetTester tester) async {
  await tester.tap(_options.first);
  await tester.pumpAndSettle();
  expect(find.byType(NetflixHoverPreview), findsOneWidget);
}

void main() {
  for (final continueCard in [false, true]) {
    testWidgets(
      '${continueCard ? 'continue' : 'poster'} keyboard, named semantics and visible focus',
      (tester) async {
        var taps = 0;
        final item = _item();
        final semantics = tester.ensureSemantics();
        await _pump(
          tester,
          continueCard
              ? NetflixContinueCard(item: item, onTap: () => taps++)
              : NetflixPosterCard(item: item, onTap: () => taps++),
        );
        final label =
            '${continueCard ? 'Continue watching' : 'Details for'} ${item.title}';
        final node = tester.getSemantics(find.bySemanticsLabel(label));
        expect(node.getSemanticsData().flagsCollection.isButton, isTrue);
        expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        final focusBorders = find.byWidgetPredicate((w) {
          if (w is! Container) return false;
          final decoration = w.foregroundDecoration;
          return decoration is BoxDecoration &&
              decoration.border is Border &&
              (decoration.border! as Border).top.color == NetflixColors.gold;
        });
        expect(focusBorders, findsOneWidget);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        expect(taps, 1);
        await tester.sendKeyEvent(LogicalKeyboardKey.space);
        expect(taps, 2);
        // The next focus target is the menu, not another card activation.
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(find.byType(NetflixHoverPreview), findsOneWidget);
        expect(taps, 2);
        semantics.dispose();
      },
    );
  }

  testWidgets('poster menu Play, Save and Rate do not also activate Details', (
    tester,
  ) async {
    var details = 0;
    var plays = 0;
    bool? saved;
    double? rating;
    await _pump(
      tester,
      NetflixRow(
        title: 'Trending',
        items: [_item()],
        onTapItem: (_) => details++,
        onPlayItem: (_) => plays++,
        onToggleListItem: (_, add) => saved = add,
        onRateItem: (_, value) => rating = value,
      ),
    );
    await tester.tapAt(
      tester.getTopLeft(find.byType(NetflixPosterCard)) + const Offset(30, 30),
    );
    expect(details, 1);
    await _openOptions(tester);
    await tester.tap(find.byTooltip('Add to My List'));
    await tester.pump();
    expect(saved, isTrue);
    await tester.tap(find.byTooltip('I like this'));
    await tester.pump();
    expect(rating, 1);
    for (final button in tester.widgetList<IconButton>(
      find.byType(IconButton),
    )) {
      if (button.onPressed != null) {
        final rect = tester.getSize(find.byWidget(button));
        expect(rect.width, greaterThanOrEqualTo(48));
        expect(rect.height, greaterThanOrEqualTo(48));
      }
    }
    expect(details, 1);
    await tester.tap(find.byTooltip('Play'));
    await tester.pumpAndSettle();
    expect(plays, 1);
    expect(details, 1);
    expect(find.byType(NetflixHoverPreview), findsNothing);
    await _openOptions(tester);
    await tester.tap(find.byTooltip('Details for ${_item().title}'));
    await tester.pumpAndSettle();
    expect(details, 2);
    expect(plays, 1);
  });

  testWidgets(
    'continue preserves Resume, separate Details, Restart and Remove',
    (tester) async {
      var details = 0;
      var resumes = 0;
      var restarts = 0;
      var removes = 0;
      await _pump(
        tester,
        NetflixContinueRow(
          items: [_item()],
          onTapItem: (_) => details++,
          subtitleOf: (_) => '12 minutes left',
          progressOf: (_) => 0.5,
          onPlayContinue: (_) => resumes++,
          onRestart: (_) => restarts++,
          onRemoveItem: (_) => removes++,
        ),
      );
      final card = find.byType(NetflixContinueCard);
      await tester.tapAt(tester.getTopLeft(card) + const Offset(80, 70));
      expect(resumes, 1);
      expect(details, 0);
      await _openOptions(tester);
      await tester.tap(find.text('Restart'));
      await tester.pumpAndSettle();
      expect(restarts, 1);
      expect(resumes, 1);
      expect(details, 0);
      await _openOptions(tester);
      await tester.tap(find.byTooltip('Details for ${_item().title}'));
      await tester.pumpAndSettle();
      expect(details, 1);
      expect(resumes, 1);
      await _openOptions(tester);
      await tester.tap(find.byTooltip('Play'));
      await tester.pumpAndSettle();
      expect(resumes, 2);
      expect(details, 1);
      final remove = find.widgetWithIcon(IconButton, Icons.close_rounded);
      expect(tester.getSize(remove), const Size(48, 48));
      expect(
        tester.getRect(remove).overlaps(tester.getRect(_options)),
        isFalse,
      );
      await tester.tap(remove);
      expect(removes, 1);
      expect(resumes, 2);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'standalone continue Details is disabled rather than resuming accidentally',
    (tester) async {
      var resumes = 0;
      await _pump(
        tester,
        NetflixContinueCard(item: _item(), onTap: () => resumes++),
      );
      await _openOptions(tester);
      final details = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.keyboard_arrow_down_rounded),
      );
      expect(details.onPressed, isNull);
      expect(find.text('Restart'), findsNothing);
      await tester.tap(find.byIcon(Icons.keyboard_arrow_down_rounded));
      expect(resumes, 0);
    },
  );

  for (final width in [360.0, 390.0, 430.0, 810.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'production grid ${width}px scale $scale has bounded 48px options and usable sheet',
        (tester) async {
          final columns = width >= 768 ? 5 : 3;
          var details = 0;
          await _pump(
            tester,
            GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                childAspectRatio: 0.67,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: columns * 2,
              itemBuilder: (_, i) => NetflixPosterCard(
                item: _item(i),
                compact: true,
                selfPreview: true,
                onTap: () => details++,
                onPlay: (_) {},
                onToggleList: (_, _) {},
                onRate: (_, _) {},
              ),
            ),
            width: width,
            textScale: scale,
          );
          for (var i = 0; i < columns; i++) {
            final card = tester.getRect(find.byType(NetflixPosterCard).at(i));
            final options = tester.getRect(_options.at(i));
            expect(options.size, const Size(48, 48));
            expect(card.contains(options.topLeft), isTrue);
            expect(card.contains(options.bottomRight), isTrue);
            expect(
              card.width,
              closeTo((width - 32 - (columns - 1) * 10) / columns, 0.1),
            );
          }
          expect(tester.takeException(), isNull);
          await _openOptions(tester);
          expect(details, 0);
          await tester.tap(find.byTooltip('I like this'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(details, 0);
        },
      );
    }
  }

  testWidgets('continue row large text leaves space for subtitle and menu', (
    tester,
  ) async {
    await _pump(
      tester,
      NetflixContinueRow(
        items: [_item()],
        onTapItem: (_) {},
        subtitleOf: (_) => 'A long subtitle with progress',
        progressOf: (_) => 0.5,
        onRestart: (_) {},
        onPlayContinue: (_) {},
        onRemoveItem: (_) {},
      ),
      width: 360,
      textScale: 2,
    );
    await _openOptions(tester);
    expect(find.text('Restart'), findsOneWidget);
    await tester.tap(find.text('Restart'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
