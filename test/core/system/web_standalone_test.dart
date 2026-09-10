import 'package:everglow/core/system/web_standalone.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards the installed-web-app inset helper.
///
/// On the VM (and native) the stub is selected: no standalone, no inset,
/// child returned untouched — so Safari tabs and native builds can never
/// shift because of this fix.
void main() {
  test('non-web stub reports no standalone and zero inset', () {
    expect(WebStandalone.isStandalone(), isFalse);
    expect(WebStandalone.safeAreaTop(), 0);
    expect(WebStandalone.probeSafeAreaTop(), 0);
  });

  testWidgets('WebStandaloneInsets returns its child untouched off-web', (
    tester,
  ) async {
    const key = Key('inner');
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: WebStandaloneInsets(
            child: SizedBox(key: key, width: 10, height: 10),
          ),
        ),
      ),
    );
    // No padding inserted: the SizedBox keeps its exact size.
    expect(find.byKey(key), findsOneWidget);
    final size = tester.getSize(find.byKey(key));
    expect(size, const Size(10, 10));
    expect(find.byType(Padding), findsNothing);
  });
}
