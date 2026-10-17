import 'dart:async';

import 'package:everglow/core/services/notification_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef _Registration = ({String username, String token, String uid});

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  const clair = (username: 'clairjassen', uid: 'clair-uid');

  test(
    'registers after a verified login and removes/revokes on logout',
    () async {
      final registrations = <String, _Registration>{};
      final events = <String>[];
      final service = NotificationService(
        permissionGranted: true,
        identityProvider: () async => clair,
        tokenProvider: () async => 'phone-token',
        tokenWriter: (username, uid, token) async {
          events.add('register');
          registrations['$username/$token'] = (
            username: username,
            token: token,
            uid: uid,
          );
        },
        tokenRemover: (username, token) async {
          events.add('remove');
          registrations.remove('$username/$token');
        },
        tokenRevoker: () async => events.add('revoke'),
      );

      await service.syncAuthSession(enabled: false);
      expect(registrations, isEmpty);
      await service.syncAuthSession(enabled: true);
      expect(registrations.keys, contains('clairjassen/phone-token'));
      expect(registrations.values.single.uid, 'clair-uid');

      await service.unregisterForLogout();
      expect(registrations, isEmpty);
      expect(events, ['register', 'remove', 'revoke']);
    },
  );

  test(
    'logging out one installation keeps the other device registered',
    () async {
      final registrations = <String, _Registration>{};

      NotificationService makeDevice(String token) => NotificationService(
        permissionGranted: true,
        identityProvider: () async => clair,
        tokenProvider: () async => token,
        tokenWriter: (username, uid, token) async {
          registrations['$username/$token'] = (
            username: username,
            token: token,
            uid: uid,
          );
        },
        tokenRemover: (username, token) async {
          registrations.remove('$username/$token');
        },
        tokenRevoker: () async {},
      );

      final phone = makeDevice('phone-token');
      final tablet = makeDevice('tablet-token');
      await Future.wait([
        phone.syncAuthSession(enabled: true),
        tablet.syncAuthSession(enabled: true),
      ]);
      await phone.unregisterForLogout();

      expect(registrations.keys, {'clairjassen/tablet-token'});
    },
  );

  test(
    'logout invalidates a pending token fetch before it can register',
    () async {
      final tokenStarted = Completer<void>();
      final tokenResult = Completer<String?>();
      final registrations = <String, _Registration>{};
      var tokenReads = 0;
      final service = NotificationService(
        permissionGranted: true,
        identityProvider: () async => clair,
        tokenProvider: () {
          tokenReads++;
          if (tokenReads == 1) {
            tokenStarted.complete();
            return tokenResult.future;
          }
          return Future.value('racing-token');
        },
        tokenWriter: (username, uid, token) async {
          registrations['$username/$token'] = (
            username: username,
            token: token,
            uid: uid,
          );
        },
        tokenRemover: (username, token) async {
          registrations.remove('$username/$token');
        },
        tokenRevoker: () async {},
      );

      final registering = service.syncAuthSession(enabled: true);
      await tokenStarted.future;
      final loggingOut = service.unregisterForLogout();
      tokenResult.complete('racing-token');
      await Future.wait([registering, loggingOut]);

      expect(registrations, isEmpty);
    },
  );

  test(
    'logout without a registered device never asks FCM for a new token',
    () async {
      var tokenReads = 0;
      var revocations = 0;
      final noIdentity = NotificationService(
        identityProvider: () async => null,
        tokenProvider: () async {
          tokenReads++;
          throw StateError('must not request a token');
        },
        tokenRevoker: () async => revocations++,
      );
      await noIdentity.unregisterForLogout();

      final coupleWithoutPushPermission = NotificationService(
        identityProvider: () async => clair,
        tokenProvider: () async {
          tokenReads++;
          throw StateError('must not request a token');
        },
        tokenRevoker: () async => revocations++,
      );
      await coupleWithoutPushPermission.unregisterForLogout();

      expect(tokenReads, 0);
      expect(revocations, 0);
    },
  );

  test('failed registration removal keeps logout fail-closed', () async {
    var revocations = 0;
    final service = NotificationService(
      permissionGranted: true,
      identityProvider: () async => clair,
      tokenProvider: () async => 'phone-token',
      tokenWriter: (_, _, _) async {},
      tokenRemover: (_, _) async => throw StateError('Firestore unavailable'),
      tokenRevoker: () async => revocations++,
    );
    await service.syncAuthSession(enabled: true);

    await expectLater(service.unregisterForLogout(), throwsStateError);
    expect(revocations, 0, reason: 'revoke only after server removal succeeds');
  });

  test(
    'logout finds a persisted device token without asking FCM for one',
    () async {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString('fcm_device_token', 'persisted-token');
      final removed = <String>[];
      var tokenReads = 0;
      var revocations = 0;
      final service = NotificationService(
        identityProvider: () async => clair,
        tokenProvider: () async {
          tokenReads++;
          throw StateError('must not request a token');
        },
        tokenRemover: (username, token) async =>
            removed.add('$username/$token'),
        tokenRevoker: () async => revocations++,
      );

      await service.unregisterForLogout();

      expect(removed, ['clairjassen/persisted-token']);
      expect(tokenReads, 0);
      expect(revocations, 1);
      expect(preferences.getString('fcm_device_token'), isNull);
    },
  );

  test(
    'an auth switch during local token save cannot register the old profile',
    () async {
      final storageStarted = Completer<void>();
      final finishStorage = Completer<void>();
      final registrations = <String, _Registration>{};
      var identityReads = 0;
      var storageWrites = 0;
      final service = NotificationService(
        permissionGranted: true,
        identityProvider: () async {
          identityReads++;
          return identityReads == 1
              ? (username: 'clairjassen', uid: 'clair-uid')
              : (username: 'khentsgdz', uid: 'khent-uid');
        },
        tokenProvider: () async => 'shared-device-token',
        tokenStorage: (token) async {
          storageWrites++;
          if (storageWrites == 1) {
            storageStarted.complete();
            await finishStorage.future;
          }
        },
        tokenWriter: (username, uid, token) async {
          registrations['$username/$token'] = (
            username: username,
            token: token,
            uid: uid,
          );
        },
        tokenRemover: (_, _) async {},
        tokenRevoker: () async {},
      );

      final oldSession = service.syncAuthSession(enabled: true);
      await storageStarted.future;
      final newSession = service.syncAuthSession(enabled: true);
      finishStorage.complete();
      await Future.wait([oldSession, newSession]);

      expect(registrations.keys, {'khentsgdz/shared-device-token'});
    },
  );

  test(
    'a late auth lookup cannot replace the newest verified session',
    () async {
      final firstIdentity = Completer<PushIdentity?>();
      var identityReads = 0;
      final registrations = <String, _Registration>{};
      final service = NotificationService(
        permissionGranted: true,
        identityProvider: () {
          identityReads++;
          return identityReads == 1
              ? firstIdentity.future
              : Future.value((username: 'khentsgdz', uid: 'khent-uid'));
        },
        tokenProvider: () async => 'current-token',
        tokenWriter: (username, uid, token) async {
          registrations['$username/$token'] = (
            username: username,
            token: token,
            uid: uid,
          );
        },
        tokenRemover: (username, token) async {
          registrations.remove('$username/$token');
        },
        tokenRevoker: () async {},
      );

      final stale = service.syncAuthSession(enabled: true);
      await service.syncAuthSession(enabled: true);
      firstIdentity.complete(clair);
      await stale;

      expect(registrations.keys, {'khentsgdz/current-token'});
    },
  );
}
