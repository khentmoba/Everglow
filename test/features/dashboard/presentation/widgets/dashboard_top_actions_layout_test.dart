import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:everglow/features/dashboard/presentation/widgets/dashboard_overlays.dart';

/// The dashboard pins its top-action buttons (creator / mood / canvas /
/// chat) over the scroll view, so the first row of that view — the
/// "EST. FEBRUARY 14, 2026" pill — has to start below them.
///
/// On phone widths the centered pill is wider than the free space between
/// the left and right buttons, so when the header started at a flat 48px
/// the pill text ran behind the canvas and chat circles on first launch
/// ("it looks ass" report). These tests pin the geometry: the drawer of
/// the pinned row ([kTopActionsInset] + [kTopActionsSize]) may never
/// cross the top of the header, on a phone or a tablet, with no overflow.
Future<void> _pumpTopArea(WidgetTester tester, Size size) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Stack(
          children: [
            // Scroll content: the header's reserve, exactly as the
            // dashboard screen pads its first sliver.
            const Padding(
              padding: EdgeInsets.only(top: kTopActionsReserve),
              child: Align(
                alignment: Alignment.topCenter,
                child: SizedBox(
                  key: Key('header'),
                  height: 40,
                  width: 200,
                  child: ColoredBox(color: Colors.red),
                ),
              ),
            ),
            // Pinned buttons, positioned exactly as DashboardOverlays
            // places the row.
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
    ),
  );
  await tester.pump();
  // No overflow warning on either small surface.
  expect(tester.takeException(), isNull);
}

void main() {
  test('top-action gaps are even', () {
    // The (partner / mood / canvas) row sits one gap left of the chat
    // circle, so all four gaps read as a single 14px rhythm. A stray
    // `right: 96` here once made the last gap 18px ("not aligned").
    expect(kTopActionsSize, 54);
    expect(kTopActionsGap, 14);
    expect(kTopActionsRowRight, 24 + kTopActionsSize + kTopActionsGap);
  });

  for (final (name, size) in [
    ('phone', const Size(390, 844)),
    ('tablet', const Size(810, 1080)),
  ]) {
    testWidgets('top-action circles share one baseline with even gaps ($name)', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                // The (partner / mood / canvas) row, positioned exactly
                // as DashboardOverlays places it.
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
                // The chat circle, positioned exactly as DashboardOverlays.
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
      // All four circles are 54px and share one top edge: no 6px dip
      // from a stray bottom margin on some buttons but not others.
      for (final r in rects) {
        expect(r.width, kTopActionsSize);
        expect(r.height, kTopActionsSize);
        expect(r.top, kTopActionsInset);
      }
      // Gaps between neighbours are all exactly one gap.
      for (var i = 0; i < 3; i++) {
        expect(
          rects[i + 1].left - rects[i].right,
          kTopActionsGap,
          reason: 'gap $i must match the intra-row gap',
        );
      }
    });

    testWidgets('dashboard header starts clear of the pinned buttons ($name)', (
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
      // And the reserved band is not needlessly tall.
      expect(header.top, lessThan(pinned.bottom + 32));
    });
  }
}
