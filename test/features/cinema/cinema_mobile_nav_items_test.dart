import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:everglow/features/cinema/presentation/widgets/netflix/netflix_nav_bar.dart';

void main() {
  group('cinemaMobileNavItems', () {
    test('guests get Anime instead of Together', () {
      final items = cinemaMobileNavItems(isCinemaOnlyUser: true);
      final labels = items.map((i) => i.label).toList();

      // Regression: Breyan / Octagram had no ride to /anime on mobile —
      // no dashboard, and the floating corner button is their logout.
      expect(labels, contains('Anime'));
      expect(labels, isNot(contains('Together')));
      expect(items.length, 5);
      expect(
        items.where((i) => i.isAnimeLink).map((i) => i.label),
        ['Anime'],
      );
    });

    test('couple keeps Together and no Anime shortcut', () {
      final items = cinemaMobileNavItems(isCinemaOnlyUser: false);
      final labels = items.map((i) => i.label).toList();

      expect(labels, contains('Together'));
      expect(labels, isNot(contains('Anime')));
      expect(items.length, 5);
      expect(items.any((i) => i.isAnimeLink), isFalse);
    });

    test('both sets share the same core tabs', () {
      final guest = cinemaMobileNavItems(isCinemaOnlyUser: true);
      final couple = cinemaMobileNavItems(isCinemaOnlyUser: false);

      for (final items in [guest, couple]) {
        final labels = items.map((i) => i.label).toList();
        expect(
          labels,
          containsAll(['Home', 'New & Popular', 'My List', 'Search']),
        );
      }
    });
  });

  group('NetflixNavBar anime link', () {
    Future<void> pumpBar(
      WidgetTester tester, {
      required List<NetflixMobileItem> items,
      required void Function(int, String?) onSelect,
      required VoidCallback onAnimeTap,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: NetflixNavBar(
              scrolled: false,
              currentIndex: 0,
              links: const [NetflixNavLink('Home', 0)],
              mobileItems: items,
              onSelect: onSelect,
              onAnimeTap: onAnimeTap,
            ),
          ),
        ),
      );
    }

    testWidgets('tapping Anime calls onAnimeTap, not onSelect', (
      WidgetTester tester,
    ) async {
      var animeTaps = 0;
      var selectCalls = 0;
      await pumpBar(
        tester,
        items: cinemaMobileNavItems(isCinemaOnlyUser: true),
        onSelect: (_, _) => selectCalls++,
        onAnimeTap: () => animeTaps++,
      );

      await tester.tap(find.text('Anime'));
      await tester.pump();

      expect(animeTaps, 1);
      expect(selectCalls, 0);
    });

    testWidgets('regular tabs still route through onSelect', (
      WidgetTester tester,
    ) async {
      var animeTaps = 0;
      final selected = <int>[];
      await pumpBar(
        tester,
        items: cinemaMobileNavItems(isCinemaOnlyUser: true),
        onSelect: (tab, _) => selected.add(tab),
        onAnimeTap: () => animeTaps++,
      );

      await tester.tap(find.text('My List'));
      await tester.pump();

      expect(selected, [3]);
      expect(animeTaps, 0);
    });

    testWidgets('Anime never renders as the active tab', (
      WidgetTester tester,
    ) async {
      await pumpBar(
        tester,
        items: cinemaMobileNavItems(isCinemaOnlyUser: true),
        onSelect: (_, _) {},
        onAnimeTap: () {},
      );

      // currentIndex is 0 and the Anime entry carries tab 0 as a filler,
      // but the link must not light up like the active Home tab.
      final animeStyle =
          tester.widget<Text>(find.text('Anime')).style!;
      final homeStyle = tester.widget<Text>(find.text('Home')).style!;
      expect(animeStyle.color, isNot(homeStyle.color));
      expect(homeStyle.color, Colors.white);
    });
  });
}
