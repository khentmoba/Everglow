import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter_test/flutter_test.dart';

import 'package:everglow/features/dashboard/presentation/widgets/deferred_section.dart';
import 'package:everglow/features/dashboard/presentation/widgets/dashboard_zone_header.dart';

class _PaintCounter extends CustomPainter {
  int paints = 0;

  @override
  void paint(Canvas canvas, Size size) => paints++;

  @override
  bool shouldRepaint(covariant _PaintCounter oldDelegate) => false;
}

/// Counts which sections actually got mounted.
class _Section extends StatefulWidget {
  const _Section({required this.id, required this.built});

  final int id;
  final Set<int> built;

  @override
  State<_Section> createState() => _SectionState();
}

class _SectionState extends State<_Section> {
  @override
  void initState() {
    super.initState();
    widget.built.add(widget.id);
  }

  @override
  Widget build(BuildContext context) =>
      SizedBox(height: 400, child: Text('section ${widget.id}'));
}

Widget harness({
  required Set<int> built,
  int sections = 20,
  int deferMs = 0,
  ScrollController? controller,
}) {
  return MaterialApp(
    home: CustomScrollView(
      controller: controller,
      slivers: [
        for (var i = 0; i < sections; i++)
          SliverToBoxAdapter(
            child: DeferredSection(
              placeholderHeight: 400,
              deferMs: deferMs,
              child: _Section(id: i, built: built),
            ),
          ),
      ],
    ),
  );
}

/// Scrolls to the very bottom of the list, deterministically.
Future<void> scrollToEnd(
  WidgetTester tester,
  ScrollController controller,
) async {
  controller.jumpTo(controller.position.maxScrollExtent);
  // Let staggered reveals land, then settle any extent change they caused.
  await tester.pumpAndSettle();
  if (controller.position.pixels < controller.position.maxScrollExtent) {
    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pump();
  }
}

void main() {
  testWidgets('landing cards mount one per frame instead of a timer burst', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final built = <int>{};
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      harness(built: built, controller: controller, deferMs: 80),
    );
    await tester.pumpAndSettle();
    final before = Set<int>.of(built);
    controller.jumpTo(3000);
    await tester.pump();
    var lastCount = built.length;
    // Several nearby cards share the same reveal deadline after a fast jump.
    await tester.pump(const Duration(milliseconds: 81));
    expect(built.length - lastCount, lessThanOrEqualTo(1));
    for (var frame = 0; frame < 6; frame++) {
      lastCount = built.length;
      await tester.pump(const Duration(milliseconds: 16));
      expect(built.length - lastCount, lessThanOrEqualTo(1));
    }
    expect(built.difference(before).length, greaterThanOrEqualTo(2));
    // Once revealed, scrolling back must not unload existing cards.
    controller.jumpTo(0);
    await tester.pumpAndSettle();
    expect(built, containsAll(before));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('queued reveals recheck a renewed fling and recover when idle', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final built = <int>{};
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      harness(built: built, controller: controller, deferMs: 80),
    );
    await tester.pumpAndSettle();
    controller.jumpTo(3000);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 81));
    final before = Set<int>.of(built);
    (controller.position as ScrollPositionWithSingleContext).goBallistic(6000);
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 100));
    // One already-granted mount can finish; waiting cards must not join it.
    expect(built.difference(before).length, lessThanOrEqualTo(1));
    (controller.position as ScrollPositionWithSingleContext).goIdle();
    await tester.pumpAndSettle();
    expect(built.difference(before).length, greaterThanOrEqualTo(2));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('disposing a queued section leaves no retry frames running', (
    tester,
  ) async {
    final built = <int>{};
    await tester.pumpWidget(harness(built: built, deferMs: 80));
    await tester.pump(const Duration(milliseconds: 81));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(tester.takeException(), isNull);
  });

  for (final width in [430.0, 810.0]) {
    testWidgets('fast fling at $width postpones new sections until slowing', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 932);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final built = <int>{};
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        harness(built: built, controller: controller, deferMs: 80),
      );
      await tester.pump(const Duration(milliseconds: 121));
      await tester
          .pumpAndSettle(); // finish the initial screen before the fling
      final before = Set<int>.of(built);
      // Real ballistic activity; jumpTo has no sustained fling velocity.
      (controller.position as ScrollPositionWithSingleContext).goBallistic(
        6000,
      );
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 100));
      expect(controller.offset, greaterThan(1000));
      expect(built, before, reason: 'do not mount cards during a fast fling');

      (controller.position as ScrollPositionWithSingleContext).goIdle();
      // Stopping must trigger recovery without another pixel notification.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 121));
      await tester.pump();
      expect(built.difference(before), isNotEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets(
    'a pending reveal waits if a fast fling starts before its timer',
    (tester) async {
      final built = <int>{};
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        harness(built: built, controller: controller, deferMs: 80),
      );
      expect(built, isEmpty);
      (controller.position as ScrollPositionWithSingleContext).goBallistic(
        6000,
      );
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 90));
      expect(built, isEmpty);
      (controller.position as ScrollPositionWithSingleContext).goIdle();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 81));
      await tester.pump();
      expect(built, isNotEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('phone cards preload beyond the old 280px margin', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final built = <int>{};
    await tester.pumpWidget(
      MaterialApp(
        home: CustomScrollView(
          scrollCacheExtent: const ScrollCacheExtent.pixels(500),
          slivers: [
            const SliverToBoxAdapter(child: SizedBox(height: 1282)),
            SliverToBoxAdapter(
              child: DeferredSection(
                deferMs: 700,
                child: _Section(id: 0, built: built),
              ),
            ),
          ],
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 121));
    expect(built, contains(0));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('stacked pair reserves both card heights before reveal', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final built = <int>{};
    await tester.pumpWidget(
      MaterialApp(
        home: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: DashboardPair(
                left: DeferredSection(
                  placeholderHeight: 400,
                  deferMs: 700,
                  child: _Section(id: 0, built: built),
                ),
                right: DeferredSection(
                  placeholderHeight: 400,
                  deferMs: 760,
                  child: _Section(id: 1, built: built),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    final reserved = tester.getSize(find.byType(DashboardPair)).height;
    expect(reserved, 812);
    await tester.pump(const Duration(milliseconds: 121));
    expect(built, {0}, reason: 'the pair must not mount in one frame');
    await tester.pump(const Duration(milliseconds: 16));
    expect(built, containsAll([0, 1]));
    expect(tester.getSize(find.byType(DashboardPair)).height, reserved);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('skipped pending sections stay deferred and load on return', (
    tester,
  ) async {
    final built = <int>{};
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      harness(built: built, deferMs: 700, controller: controller),
    );
    controller.jumpTo(3000);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 710));
    expect(built, isNot(contains(0)));
    controller.jumpTo(0);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 710));
    expect(built, contains(0));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('unchanged section artwork is reused while scrolling', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    final painter = _PaintCounter();
    await tester.pumpWidget(
      MaterialApp(
        home: CustomScrollView(
          controller: controller,
          slivers: [
            SliverToBoxAdapter(
              child: DeferredSection(
                child: CustomPaint(
                  painter: painter,
                  size: const Size(400, 1200),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 3000)),
          ],
        ),
      ),
    );
    await tester.pump();
    final initial = painter.paints;
    for (var i = 1; i <= 10; i++) {
      controller.jumpTo(i * 10);
      await tester.pump();
    }
    expect(painter.paints, initial);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('phone reveal delay is bounded instead of waiting 700ms', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final built = <int>{};
    await tester.pumpWidget(harness(built: built, deferMs: 700));
    await tester.pump(const Duration(milliseconds: 121));
    expect(built, contains(0));
    expect(built, isNot(contains(19)));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('hidden app defers section work and reveals on resume', (
    tester,
  ) async {
    final built = <int>{};
    final spacer = ValueNotifier<double>(3000);
    addTearDown(spacer.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: ValueListenableBuilder<double>(
                valueListenable: spacer,
                builder: (_, height, _) => SizedBox(height: height),
              ),
            ),
            SliverToBoxAdapter(
              child: DeferredSection(child: _Section(id: 1, built: built)),
            ),
          ],
        ),
      ),
    );
    await tester.pump();
    expect(built, isEmpty);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    spacer.value = 0;
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(built, isEmpty);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump();
    expect(built, contains(1));
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('reveals through the dashboard wrapper patterns', (tester) async {
    // Mirrors how the dashboard actually uses this widget: an entrance-motion
    // wrapper around the child, and one DeferredSection per column of a
    // DashboardPair on phone width.
    final built = <int>{};
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: DeferredSection(
                placeholderHeight: 200,
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 300),
                  builder: (context, opacity, child) =>
                      Opacity(opacity: opacity, child: child),
                  child: _Section(id: 0, built: built),
                ),
              ),
            ),
            // The pair's two halves each defer on their own.
            SliverToBoxAdapter(
              child: Column(
                children: [
                  DeferredSection(
                    placeholderHeight: 220,
                    child: _Section(id: 1, built: built),
                  ),
                  DeferredSection(
                    placeholderHeight: 220,
                    child: _Section(id: 2, built: built),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(built, containsAll(<int>[0, 1]));
    expect(find.text('section 0'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a section reveals when it moves into range without a scroll', (
    tester,
  ) async {
    // The failure that must never come back: a visibility check that quietly
    // stops firing leaves the section as an empty placeholder forever (this is
    // how the Together zone turned into a grey slab). Nothing notifies here —
    // no scroll event, no dependency change — so only the safety net can save
    // it.
    final built = <int>{};
    final spacer = ValueNotifier<double>(3000);
    addTearDown(spacer.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: ValueListenableBuilder<double>(
                valueListenable: spacer,
                builder: (context, height, _) => SizedBox(height: height),
              ),
            ),
            SliverToBoxAdapter(
              child: DeferredSection(
                placeholderHeight: 400,
                child: _Section(id: 1, built: built),
              ),
            ),
          ],
        ),
      ),
    );
    await tester.pump();
    expect(built, isNot(contains(1)));

    // The section is now at the top of the viewport, but nothing told it so.
    spacer.value = 0;
    await tester.pump(); // applies the new layout
    await tester.pump(const Duration(milliseconds: 500)); // safety-net tick
    await tester.pump(); // builds the revealed section

    expect(built, contains(1));
  });

  testWidgets('a CustomScrollView builds every sliver child eagerly', (
    tester,
  ) async {
    // The fact this whole widget exists for: inside a CustomScrollView the
    // framework skips layout and paint for far-away slivers, but it still
    // *builds* them all. So laziness has to come from the child, not the sliver.
    final built = <int>{};
    await tester.pumpWidget(
      MaterialApp(
        home: CustomScrollView(
          slivers: [
            for (var i = 0; i < 20; i++)
              SliverToBoxAdapter(
                child: _Section(id: i, built: built),
              ),
          ],
        ),
      ),
    );

    expect(built.length, 20);
  });

  testWidgets('far-below sections stay unmounted until scrolled to', (
    tester,
  ) async {
    final built = <int>{};
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(harness(built: built, controller: controller));
    await tester.pump();

    expect(built, isNotEmpty, reason: 'the visible sections must still build');
    expect(built, isNot(contains(19)), reason: 'far sections must not build');
    expect(
      built.length,
      lessThanOrEqualTo(4),
      reason: 'cold frame 1 mounts <= 4 sections',
    );

    await scrollToEnd(tester, controller);

    expect(built, contains(19));
    expect(tester.takeException(), isNull);
  });

  testWidgets('deferMs never mounts a section that is offscreen', (
    tester,
  ) async {
    // The regression that made the whole dashboard mount on web: the old web
    // branch waited `deferMs` and then revealed regardless of position.
    final built = <int>{};
    await tester.pumpWidget(harness(built: built, deferMs: 40));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));

    expect(built, isNot(contains(19)));
    expect(built.length, lessThanOrEqualTo(4));
  });

  testWidgets('a section that scrolls into range builds, and only once', (
    tester,
  ) async {
    final built = <int>{};
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      harness(built: built, sections: 6, controller: controller),
    );
    await tester.pump();
    final before = built.length;

    controller.jumpTo(1200);
    await tester.pump();
    await tester.pump();

    expect(before, lessThan(6));
    expect(built.length, greaterThan(before));
    expect(tester.takeException(), isNull);
  });
}
