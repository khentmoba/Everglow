import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:everglow/core/system/tv_mode.dart';
import 'package:everglow/features/entry/presentation/widgets/passcode_input.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TvMode.isTvMode.value = true;
  });

  tearDown(() {
    TvMode.isTvMode.value = false;
  });

  testWidgets('remote number keys type digits directly into PasscodeInput',
      (tester) async {
    String currentInput = '';
    final entered = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return PasscodeInput(
                input: currentInput,
                onDigitPressed: (d) {
                  entered.add(d);
                  setState(() => currentInput += d);
                },
                onBackspace: () {
                  if (currentInput.isNotEmpty) {
                    setState(
                      () => currentInput = currentInput.substring(
                        0,
                        currentInput.length - 1,
                      ),
                    );
                  }
                },
                onClear: () {
                  setState(() => currentInput = '');
                },
              );
            },
          ),
        ),
      ),
    );

    // Press remote digits 1, 2, 3
    await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
    await tester.pump();
    expect(currentInput, '1');

    await tester.sendKeyEvent(LogicalKeyboardKey.numpad2);
    await tester.pump();
    expect(currentInput, '12');

    // Press backspace
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pump();
    expect(currentInput, '1');

    // Press escape (clear)
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(currentInput, '');
  });

  testWidgets('Clear button is present and clears the input on TV',
      (tester) async {
    String currentInput = '123';
    bool cleared = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PasscodeInput(
            input: currentInput,
            onDigitPressed: (_) {},
            onBackspace: () {},
            onClear: () => cleared = true,
          ),
        ),
      ),
    );

    final clearFinder = find.byIcon(Icons.refresh_rounded);
    expect(clearFinder, findsOneWidget);
    await tester.tap(clearFinder);
    await tester.pump();

    expect(cleared, isTrue);
  });

  testWidgets(
      'D-pad arrows traverse between key buttons and Select/Enter enters digit',
      (tester) async {
    String currentInput = '';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return PasscodeInput(
                input: currentInput,
                onDigitPressed: (d) => setState(() => currentInput += d),
                onBackspace: () {},
                onClear: () {},
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Focus starts on key '1'. Press Enter -> enters '1'.
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(currentInput, '1');

    // Move D-pad right to '2'. Press Select -> enters '2'.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump();
    expect(currentInput, '12');

    // Move D-pad down from '2' to '5'. Press Enter -> enters '5'.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(currentInput, '125');
  });

  testWidgets('phone touch mode does not highlight key 1 on initial load',
      (tester) async {
    TvMode.isTvMode.value = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PasscodeInput(
            input: '',
            onDigitPressed: (_) {},
            onBackspace: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final key1FocusFinder = find.ancestor(
      of: find.text('1'),
      matching: find.byType(Focus),
    ).first;
    final focusWidget = tester.widget<Focus>(key1FocusFinder);
    expect(focusWidget.focusNode?.hasPrimaryFocus ?? false, isFalse);
    expect(FocusManager.instance.primaryFocus, isNot(focusWidget.focusNode));
  });

  testWidgets('TV mode autofocuses key 1 on initial load', (tester) async {
    TvMode.isTvMode.value = true;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PasscodeInput(
            input: '',
            onDigitPressed: (_) {},
            onBackspace: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final key1FocusFinder = find.ancestor(
      of: find.text('1'),
      matching: find.byType(Focus),
    ).first;
    final focusWidget = tester.widget<Focus>(key1FocusFinder);
    expect(focusWidget.focusNode?.hasPrimaryFocus, isTrue);
    expect(FocusManager.instance.primaryFocus, equals(focusWidget.focusNode));
  });
}
