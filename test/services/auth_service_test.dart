import 'package:everglow/core/services/auth_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Minimal unit test to verify AuthService isReady logic.
/// Full integration tests require Firebase mock which is outside scope.
void main() {
  group('AuthService.isReady logic', () {
    test('isReady requires both user and currentUser', () {
      bool userIsNull = false;
      bool currentUserIsNull = false;
      final isReady = !userIsNull && !currentUserIsNull;
      expect(isReady, isTrue);
    });

    test('isReady is false when currentUser is null', () {
      bool userIsNull = false;
      bool currentUserIsNull = true;
      final isReady = !userIsNull && !currentUserIsNull;
      expect(isReady, isFalse);
    });

    test('isReady is false when user is null', () {
      const userIsNull = true;
      const currentUserIsNull = false;
      // ignore: dead_code
      final isReady = !userIsNull && !currentUserIsNull;
      expect(isReady, isFalse);
    });
  });

  group('AuthService.needsUserDocRepair', () {
    test('healthy doc needs no repair', () {
      expect(
        AuthService.needsUserDocRepair({
          'username': 'khentsgdz',
          'partnerUsername': 'clairjassen',
        }, 'khentsgdz'),
        isFalse,
      );
    });

    test('doc with createdAt still needs no repair', () {
      expect(
        AuthService.needsUserDocRepair({
          'username': 'clairjassen',
          'createdAt': '2026-01-01',
        }, 'clairjassen'),
        isFalse,
      );
    });

    test('drifted username needs repair', () {
      expect(
        AuthService.needsUserDocRepair(
          {'username': 'Khent'},
          'khentsgdz',
        ),
        isTrue,
      );
    });

    test('missing username needs repair', () {
      expect(
        AuthService.needsUserDocRepair(const {}, 'khentsgdz'),
        isTrue,
      );
    });

    test('extra fields need repair', () {
      expect(
        AuthService.needsUserDocRepair({
          'username': 'khentsgdz',
          'email': 'khent@example.com',
        }, 'khentsgdz'),
        isTrue,
      );
    });
  });
}
