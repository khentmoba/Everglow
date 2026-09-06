import 'package:everglow/core/system/app_update_service_web.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parseBuild extracts the build stamp', () {
    expect(
      AppUpdateService.parseBuild('{"build": "6.0.0+1-abc1234"}\n'),
      '6.0.0+1-abc1234',
    );
  });

  test('parseBuild returns null for garbage', () {
    expect(AppUpdateService.parseBuild('not json'), isNull);
    expect(AppUpdateService.parseBuild('{}'), isNull);
    expect(AppUpdateService.parseBuild('{"build": ""}'), isNull);
    expect(AppUpdateService.parseBuild('{"build": 42}'), isNull);
  });
}
