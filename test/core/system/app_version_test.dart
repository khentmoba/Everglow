import 'package:everglow/core/system/app_version.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AppVersion.current is a semantic version', () {
    expect(RegExp(r'^\d+\.\d+\.\d+').hasMatch(AppVersion.current), isTrue);
    expect(AppVersion.display, isNot(contains('+')));
  });
}
