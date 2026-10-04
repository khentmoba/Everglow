import 'package:everglow/shared/widgets/everglow/everglow_marquee.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pins the PWA scroll-jank fix: the marquee drift pauses while the
/// enclosing vertical list moves (so scroll raster gets the single web
/// thread) and resumes once it settles.
void main() {
  final marqueeKey = GlobalKey();

  late ScrollController scroll;
  setUp(() => scroll = ScrollController());
  tearDown(() => scroll.dispose());

  Widget harness({double spacer = 0}) => MaterialApp(
    home: Scaffold(
      body: CustomScrollView(
        controller: scroll,
        slivers: [
          SliverToBoxAdapter(child: SizedBox(height: spacer)),
          SliverToBoxAdapter(
            child: EverglowMarquee(
              key: marqueeKey,
              height: 120,
              children: const [
                SizedBox(width: 200, height: 120, child: Text('a')),
                SizedBox(width: 200, height: 120, child: Text('b')),
              ],
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 2000)),
        ],
      ),
    ),
  );

  // Reads the @visibleForTesting hook on the marquee state.
  // ignore: avoid_dynamic_calls
  bool isDrifting() => (marqueeKey.currentState as dynamic).isDrifting as bool;

  testWidgets('drift pauses during scroll and resumes after settle', (
    tester,
  ) async {
    await tester.pumpWidget(harness());
    // Mount also emits one scroll notification from the initial layout;
    // let that settle so the drift is running before the real gesture.
    await tester.pump(const Duration(milliseconds: 500));
    expect(isDrifting(), isTrue);

    // A drag (no inertia, deterministic): drift must yield while it moves.
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -50));
    await tester.pump();
    expect(isDrifting(), isFalse);

    // After the scroll settles, drift comes back on its own.
    await tester.pump(const Duration(milliseconds: 500));
    expect(isDrifting(), isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('jumping a row into view resumes after current layout settles', (
    tester,
  ) async {
    await tester.pumpWidget(harness(spacer: 1000));
    scroll.jumpTo(10);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(isDrifting(), isFalse);
    scroll.jumpTo(950);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(isDrifting(), isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('pending settle never restarts a backgrounded marquee', (
    tester,
  ) async {
    await tester.pumpWidget(harness());
    await tester.pump(const Duration(milliseconds: 500));
    expect(isDrifting(), isTrue);
    scroll.jumpTo(50);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    addTearDown(
      () => tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(isDrifting(), isFalse);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(isDrifting(), isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
