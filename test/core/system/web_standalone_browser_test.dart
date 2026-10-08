@TestOn('browser')
library;

import 'dart:js_interop';

import 'package:everglow/core/system/web_standalone.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

@JS('eval')
external JSAny? _eval(JSString script);

void js(String script) => _eval(script.toJS);

void main() {
  setUp(() {
    js('''
      window.egOriginalStyle = window.getComputedStyle;
      window.egOriginalStandalone = Object.getOwnPropertyDescriptor(navigator, 'standalone');
      window.egInsets = {paddingTop: '59px', paddingRight: '0px', paddingBottom: '34px', paddingLeft: '0px'};
      Object.defineProperty(navigator, 'standalone', {value: true, configurable: true});
      window.getComputedStyle = function(node) {
        if (node.style.paddingTop === 'env(safe-area-inset-top)') return window.egInsets;
        return window.egOriginalStyle.apply(this, arguments);
      };
    ''');
  });

  tearDown(() {
    js('''
      window.getComputedStyle = window.egOriginalStyle;
      if (window.egOriginalStandalone) {
        Object.defineProperty(navigator, 'standalone', window.egOriginalStandalone);
      } else {
        delete navigator.standalone;
      }
      delete window.egOriginalStyle;
      delete window.egOriginalStandalone;
      delete window.egInsets;
    ''');
  });

  testWidgets('system insets protect controls without shrinking backgrounds', (
    tester,
  ) async {
    late MediaQueryData measured;
    const background = Key('background');
    const content = Key('content');
    Future<void> mount({double keyboard = 0}) => tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(viewInsets: EdgeInsets.only(bottom: keyboard)),
          child: WebStandaloneInsets(
            child: Builder(
              builder: (context) {
                measured = MediaQuery.of(context);
                return const Stack(
                  children: [
                    Positioned.fill(
                      child: ColoredBox(key: background, color: Colors.black),
                    ),
                    SafeArea(child: SizedBox.expand(key: content)),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );

    await mount();
    expect(measured.padding, const EdgeInsets.only(top: 59, bottom: 34));
    expect(tester.getTopLeft(find.byKey(background)), Offset.zero);
    expect(
      tester.getSize(find.byKey(background)),
      tester.view.physicalSize / tester.view.devicePixelRatio,
    );
    expect(tester.getTopLeft(find.byKey(content)).dy, 59);
    expect(
      tester.getBottomRight(find.byKey(background)).dy -
          tester.getBottomRight(find.byKey(content)).dy,
      34,
    );

    await mount(keyboard: 300);
    expect(measured.padding.bottom, 0);
    expect(measured.viewPadding.bottom, 34);

    js(
      "window.egInsets = {paddingTop: '0px', paddingRight: '44px', paddingBottom: '21px', paddingLeft: '44px'}; window.dispatchEvent(new Event('resize'));",
    );
    await tester.pump();
    expect(measured.padding, const EdgeInsets.fromLTRB(44, 0, 44, 0));
    expect(measured.viewPadding, const EdgeInsets.fromLTRB(44, 0, 44, 21));
    await tester.pump(const Duration(milliseconds: 500));
  });

  test('browser tabs ignore system overlaps and bad measurements are rejected', () {
    js(
      "Object.defineProperty(navigator, 'standalone', {value: false, configurable: true});",
    );
    expect(WebStandalone.safeAreaPadding(), EdgeInsets.zero);
    js(
      "Object.defineProperty(navigator, 'standalone', {value: true, configurable: true}); window.egInsets = {paddingTop: 'NaNpx', paddingRight: '-1px', paddingBottom: '200px', paddingLeft: '44px'};",
    );
    expect(WebStandalone.safeAreaPadding(), const EdgeInsets.only(left: 44));
  });
}
