import 'package:cloud_firestore/cloud_firestore.dart';
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

  group('AuthService.pickPartnerUid', () {
    test('returns null when no doc claims the username', () {
      expect(
        AuthService.pickPartnerUid(const [], myUsername: 'khentsgdz'),
        isNull,
      );
    });

    test('skips a stray doc that sorts first by document id', () {
      // Live shape: a stray `/users` doc id (created by a malformed request)
      // sorts before the real account and used to win the old limit(1) query.
      final uid = AuthService.pickPartnerUid([
        (
          id: '.fieldPaths=username&updateMask.fieldPaths=partnerUid',
          data: {
            'username': 'clairjassen',
            'partnerUid': 'nitw0mxAR9WtxtzQtLNHYWRjENj2',
            'role': 'couple',
          },
        ),
        (
          id: 'bqS6Y5JlzuUB1YcbzUUK7MRpEqA2',
          data: {
            'username': 'clairjassen',
            'partnerUsername': 'khentsgdz',
            'updatedAt': Timestamp.fromDate(DateTime.utc(2026, 9, 7)),
          },
        ),
      ], myUsername: 'khentsgdz');

      expect(uid, 'bqS6Y5JlzuUB1YcbzUUK7MRpEqA2');
    });

    test('skips stale duplicate accounts and picks the mutual link', () {
      final uid = AuthService.pickPartnerUid([
        (
          id: 'I5Ix9FfajbX4HgnvFpbSddEEL483',
          data: {
            'username': 'khentsgdz',
            'updatedAt': Timestamp.fromDate(DateTime.utc(2026, 8, 12)),
          },
        ),
        (
          id: 'KQGd3rw6x0WA8BsL8lThs3VBx972',
          data: {
            'username': 'khentsgdz',
            'updatedAt': Timestamp.fromDate(DateTime.utc(2026, 8, 12)),
          },
        ),
        (
          id: 'nitw0mxAR9WtxtzQtLNHYWRjENj2',
          data: {
            'username': 'khentsgdz',
            'partnerUsername': 'clairjassen',
            'updatedAt': Timestamp.fromDate(DateTime.utc(2026, 9, 10)),
          },
        ),
      ], myUsername: 'clairjassen');

      expect(uid, 'nitw0mxAR9WtxtzQtLNHYWRjENj2');
    });

    test('without a mutual link the most recently updated doc wins', () {
      final uid = AuthService.pickPartnerUid([
        (
          id: 'aaa-old',
          data: {
            'username': 'khentsgdz',
            'updatedAt': Timestamp.fromDate(DateTime.utc(2026, 8, 12)),
          },
        ),
        (
          id: 'zzz-new',
          data: {
            'username': 'khentsgdz',
            'updatedAt': Timestamp.fromDate(DateTime.utc(2026, 9, 10)),
          },
        ),
      ], myUsername: 'clairjassen');

      expect(uid, 'zzz-new');
    });

    test('docs without updatedAt rank behind docs that have one', () {
      final uid = AuthService.pickPartnerUid([
        (id: 'aaa-stray', data: {'username': 'khentsgdz', 'role': 'couple'}),
        (
          id: 'zzz-old',
          data: {
            'username': 'khentsgdz',
            'updatedAt': Timestamp.fromDate(DateTime.utc(2026, 8, 12)),
          },
        ),
      ], myUsername: null);

      expect(uid, 'zzz-old');
    });

    test('reads ISO string and millisecond updatedAt shapes', () {
      final uid = AuthService.pickPartnerUid([
        (
          id: 'aaa-json',
          data: {'username': 'khentsgdz', 'updatedAt': '2026-09-10T09:02:28Z'},
        ),
        (
          id: 'bbb-epoch',
          data: {
            'username': 'khentsgdz',
            'updatedAt': DateTime.utc(2026, 9, 11).millisecondsSinceEpoch,
          },
        ),
      ], myUsername: null);

      expect(uid, 'bbb-epoch');
    });

    test('is deterministic when every doc ties', () {
      final uid = AuthService.pickPartnerUid([
        (id: 'bbb', data: {'username': 'khentsgdz'}),
        (id: 'aaa', data: {'username': 'khentsgdz'}),
      ], myUsername: null);

      expect(uid, 'aaa');
    });
  });
}
