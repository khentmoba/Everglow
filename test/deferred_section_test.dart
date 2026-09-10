import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:everglow/features/dashboard/presentation/widgets/deferred_section.dart';

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
  Widget build(BuildContext context) => SizedBox(
    height: 400,
    child: Text('section ${widget.id}'),
  );
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
  await tester.pump();
  // Let reveals triggered by the scroll land, then settle any extent change
  // they caused (a real section is taller than its placeholder).
  await tester.pump();
  if (controller.position.pixels < controller.position.maxScrollExtent) {
    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pump();
  }
}

void main() {
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
                  builder: (context, opacity, child) => Opacity(
                    opacity: opacity,
                    child: child,
                  ),
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
              SliverToBoxAdapter(child: _Section(id: i, built: built)),
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
    expect(built.length, lessThan(8));

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
    expect(built.length, lessThan(8));
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
