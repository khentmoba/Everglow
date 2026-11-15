import 'package:everglow/shared/widgets/everglow/everglow_marquee.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
                SizedBox(width: 200, height: 120, child: Text('c')),
              ],
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 2000)),
        ],
      ),
    ),
  );

  // ignore: avoid_dynamic_calls
  bool isDrifting() => (marqueeKey.currentState as dynamic).isDrifting as bool;

  testWidgets('drift pauses during scroll and resumes after settle', (
    tester,
  ) async {
    await tester.pumpWidget(harness());
    await tester.pump(const Duration(milliseconds: 500));
    expect(isDrifting(), isTrue);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -50));
    await tester.pump();
    expect(isDrifting(), isFalse);

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

  testWidgets('phone viewport stays static across scroll and settle', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(harness());
    await tester.pump(const Duration(milliseconds: 500));
    expect(isDrifting(), isFalse);

    scroll.jumpTo(120);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(isDrifting(), isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
