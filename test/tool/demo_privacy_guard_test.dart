import 'package:flutter_test/flutter_test.dart';

import '../../tool/ci/check_demo_privacy.dart';

void main() {
  test('rejects personal bundled images and remote photo URLs', () {
    expect(
      demoPrivacyFailures("'assets/images/milestones/kiss.jpg'"),
      isNotEmpty,
    );
    expect(
      demoPrivacyFailures("'https://storage.example/private.jpg'"),
      isNotEmpty,
    );
    expect(demoPrivacyFailures("'assets/images/demo/poster-1.jpg'"), isEmpty);
    expect(demoPrivacyFailures("'/perf-fixtures/poster-1.jpg'"), isEmpty);
  });
}
