import 'package:everglow/shared/utils/scroll_memory.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ScrollMemory.debugReset();
    RememberedScrollController.saveDelay = Duration.zero;
  });

  tearDown(() {
    RememberedScrollController.saveDelay = const Duration(milliseconds: 500);
  });

  Future<double?> storedSpot(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble('scroll:$key');
  }

  Future<void> pumpScrollable(
    WidgetTester tester,
    RememberedScrollController controller,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView.builder(
            controller: controller,
            itemCount: 100,
            itemExtent: 50,
            itemBuilder: (_, i) => Text('row $i'),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  test('preload makes controllers start at the saved spot', () async {
    SharedPreferences.setMockInitialValues({'scroll:journal:entries': 320.0});
    await ScrollMemory.preload();

    final controller = RememberedScrollController('journal:entries');
    addTearDown(controller.dispose);
    expect(controller.initialScrollOffset, 320.0);
  });

  test('unknown lists start at the top', () async {
    await ScrollMemory.preload();

    final controller = RememberedScrollController('books:home');
    addTearDown(controller.dispose);
    expect(controller.initialScrollOffset, 0);
  });

  testWidgets('scrolling is written to the device shortly after', (
    tester,
  ) async {
    final controller = RememberedScrollController('journal:entries');
    addTearDown(controller.dispose);
    await pumpScrollable(tester, controller);

    controller.jumpTo(250);
    await tester.pump(const Duration(milliseconds: 50));

    expect(await storedSpot('journal:entries'), 250);
  });

  testWidgets('scrolling back to the top clears the saved spot', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'scroll:journal:entries': 320.0});
    await ScrollMemory.preload();
    final controller = RememberedScrollController('journal:entries');
    addTearDown(controller.dispose);
    await pumpScrollable(tester, controller);

    controller.jumpTo(0);
    await tester.pump(const Duration(milliseconds: 50));

    expect(await storedSpot('journal:entries'), isNull);
  });

  testWidgets('a rebuilt controller reopens at the last spot', (tester) async {
    final first = RememberedScrollController('books:home');
    addTearDown(first.dispose);
    await pumpScrollable(tester, first);
    first.jumpTo(150);
    await tester.pump(const Duration(milliseconds: 50));

    // Leaving and returning to the page later in the same boot.
    final second = RememberedScrollController('books:home');
    addTearDown(second.dispose);
    expect(second.initialScrollOffset, 150);
  });
}
