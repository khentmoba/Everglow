import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('web shell preserves browser and assistive zoom', () {
    final html = File('web/index.html').readAsStringSync();

    expect(html, isNot(contains('user-scalable=no')));
    expect(html, isNot(contains('maximum-scale=1.0')));
    expect(html, contains('touch-action: pan-x pan-y pinch-zoom'));
    expect(html, isNot(contains("addEventListener('gesturestart'")));
    expect(html, isNot(contains("addEventListener('gesturechange'")));
  });
}
