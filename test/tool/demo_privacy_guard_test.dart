import 'package:flutter_test/flutter_test.dart';

import '../../tool/ci/check_demo_privacy.dart';

void main() {
  test('public login cannot embed private milestone seed records', () {
    expect(
      privateSeedFailures("Milestone(description: 'private story')"),
      isNotEmpty,
    );
    expect(
      privateSeedFailures("db.collection('milestones').add(data)"),
      isNotEmpty,
    );
    expect(privateSeedFailures('showLoginDoor()'), isEmpty);
  });
  test('private photos stay out of the public bundle and Git index', () {
    expect(
      privateBundleFailures('  - assets/images/milestones/\n', []),
      isNotEmpty,
    );
    expect(privateBundleFailures('  - assets/images/\n', []), isNotEmpty);
    expect(
      privateBundleFailures('', ['assets/images/milestones/private.jpg']),
      isNotEmpty,
    );
    expect(privateBundleFailures('  - assets/images/demo/\n', []), isEmpty);
  });
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
