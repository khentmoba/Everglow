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
  for (final (name, size) in [
    ('phone', const Size(390, 844)),
    ('tablet', const Size(810, 1080)),
  ]) {
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
