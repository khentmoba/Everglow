import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:everglow/features/dashboard/presentation/widgets/dashboard_overlays.dart';

Future<void> _pumpTopArea(
  WidgetTester tester,
  Size size, {
  EdgeInsets insets = EdgeInsets.zero,
  ScrollController? controller,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: size, padding: insets, viewPadding: insets),
        child: Scaffold(
          body: SafeArea(
            top: false,
            child: Stack(
              children: [
                CustomScrollView(
                  controller: controller,
                  slivers: [
                    SliverPadding(
                      padding: EdgeInsets.only(top: insets.top),
                      sliver: SliverMainAxisGroup(
                        slivers: [
                          const SliverToBoxAdapter(
                            child: Padding(
                              padding: EdgeInsets.only(top: kTopActionsReserve),
                              child: Center(
                                child: SizedBox(
                                  key: Key('header'),
                                  height: 40,
                                  width: 200,
                                  child: ColoredBox(color: Colors.red),
                                ),
                              ),
                            ),
                          ),
                          SliverToBoxAdapter(
                            child: SizedBox(height: size.height * 2),
                          ),
                          const SliverToBoxAdapter(
                            child: SizedBox.shrink(key: Key('zone-anchor')),
                          ),
                          SliverToBoxAdapter(
                            child: SizedBox(height: size.height),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: EdgeInsets.only(top: insets.top),
                  child: Stack(
                    children: [
                      Positioned(
                        top: kTopActionsInset,
                        left: 24,
                        child: Container(
                          key: const Key('pinned'),
                          width: kTopActionsSize,
                          height: kTopActionsSize,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  expect(tester.takeException(), isNull);
}

void main() {
  test('top-action gaps are even', () {
    expect(kTopActionsSize, 54);
    expect(kTopActionsGap, 14);
    expect(kTopActionsRowRight, 24 + kTopActionsSize + kTopActionsGap);
  });

  for (final (name, size) in [
    ('phone', const Size(390, 844)),
    ('tablet', const Size(810, 1080)),
  ]) {
    testWidgets(
      'top-action circles share one baseline with even gaps ($name)',
      (tester) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Stack(
                children: [
                  Positioned(
                    top: kTopActionsInset,
                    right: kTopActionsRowRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(
                          key: Key('c0'),
                          width: kTopActionsSize,
                          height: kTopActionsSize,
                        ),
                        SizedBox(width: kTopActionsGap),
                        SizedBox(
                          key: Key('c1'),
                          width: kTopActionsSize,
                          height: kTopActionsSize,
                        ),
                        SizedBox(width: kTopActionsGap),
                        SizedBox(
                          key: Key('c2'),
                          width: kTopActionsSize,
                          height: kTopActionsSize,
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: kTopActionsInset,
                    right: 24,
                    child: SizedBox(
                      key: Key('c3'),
                      width: kTopActionsSize,
                      height: kTopActionsSize,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);

        final rects = [
          for (var i = 0; i < 4; i++) tester.getRect(find.byKey(Key('c$i'))),
        ];
        for (final r in rects) {
          expect(r.width, kTopActionsSize);
          expect(r.height, kTopActionsSize);
          expect(r.top, kTopActionsInset);
        }
        for (var i = 0; i < 3; i++) {
          expect(
            rects[i + 1].left - rects[i].right,
            kTopActionsGap,
            reason: 'gap $i must match the intra-row gap',
          );
        }
      },
    );

    testWidgets(
      'scroll content underlaps the clock but fixed controls stay safe ($name)',
      (tester) async {
        final controller = ScrollController();
        addTearDown(controller.dispose);
        const insets = EdgeInsets.only(top: 59, bottom: 34);
        await _pumpTopArea(
          tester,
          size,
          insets: insets,
          controller: controller,
        );
        final viewport = tester.getRect(find.byType(CustomScrollView));
        final pinned = tester.getRect(find.byKey(const Key('pinned')));
        final header = tester.getRect(find.byKey(const Key('header')));
        expect(viewport.top, 0);
        expect(viewport.bottom, size.height - insets.bottom);
        expect(pinned.top, insets.top + kTopActionsInset);
        expect(header.top, insets.top + kTopActionsReserve);
        expect(header.top, greaterThan(pinned.bottom));

        controller.jumpTo(125);
        await tester.pump();
        final scrolled = tester.getRect(find.byKey(const Key('header')));
        expect(scrolled.center.dy, inExclusiveRange(0, insets.top));
        final target = tester.renderObject(find.byKey(const Key('header')));
        expect(
          tester
              .hitTestOnBinding(scrolled.center)
              .path
              .any((e) => e.target == target),
          isTrue,
          reason:
              'content must remain inside the viewport above the safe inset',
        );
        expect(tester.getRect(find.byKey(const Key('pinned'))), pinned);

        final anchor = find.byKey(
          const Key('zone-anchor'),
          skipOffstage: false,
        );
        await Scrollable.ensureVisible(
          tester.element(anchor),
          alignment: 0.05 + 0.95 * insets.top / viewport.height,
        );
        await tester.pump();
        expect(
          tester.getTopLeft(anchor).dy,
          closeTo(insets.top + 0.05 * (viewport.height - insets.top), 0.01),
          reason: 'zone jumps must retain their previous safe-area landing',
        );
        expect(tester.getRect(find.byKey(const Key('pinned'))), pinned);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('dashboard header starts clear of the pinned buttons with no overflow ($name)', (
      tester,
    ) async {
      await _pumpTopArea(tester, size);
      final header = tester.getRect(find.byKey(const Key('header')));
      final pinned = tester.getRect(find.byKey(const Key('pinned')));
      expect(
        header.top,
        greaterThanOrEqualTo(pinned.bottom),
        reason: 'the anniversary pill must not slide behind the top buttons',
      );
      expect(header.top, lessThan(pinned.bottom + 32));
    });
  }
}
