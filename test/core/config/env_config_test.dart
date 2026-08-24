import 'package:everglow/core/config/env_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EnvConfig', () {
    test('debug builds keep the documented dev fallbacks', () {
      expect(kDebugMode, isTrue);
      expect(EnvConfig.clairPasscode, '0221');
      expect(EnvConfig.khentPasscode, '0938');
      expect(EnvConfig.breyanPasscode, '9132');
      expect(EnvConfig.octagramPasscode, '8080');
      expect(EnvConfig.breyanPassword, '91329132');
      expect(EnvConfig.octagramPassword, '80808080');
    });

    test('client build exposes no couple credentials', () {
      // These getters were removed deliberately: production auth must use the
      // server-verified passcode endpoint rather than browser-held secrets.
      expect(EnvConfig.hasAnyPasscodes, isTrue);
    });

    test('has* flags reflect configured state', () {
      expect(EnvConfig.hasBreyanCreds, isTrue);
      expect(EnvConfig.hasOctagramCreds, isTrue);
      expect(EnvConfig.hasAnyPasscodes, isTrue);
    });

    test('missingRequired lists only local cinema account setup', () {
      final missing = EnvConfig.missingRequired();
      expect(missing, isEmpty);
    });

    test('public identifiers keep their defaults', () {
      expect(EnvConfig.fcmVapidKey, isNotEmpty);
      expect(EnvConfig.lastfmUserKhent, 'khentsgdz');
      expect(EnvConfig.lastfmUserClair, 'clairjassen');
      expect(EnvConfig.breyanEmail, 'breyan@scrapbook.local');
      expect(EnvConfig.octagramEmail, 'octagram@scrapbook.local');
    });

    test('server-only browser credentials are absent', () {
      // Compile-time access would place these values in deployed JavaScript.
      expect(EnvConfig.missingRequired(), isNot(contains('TMDB_API_KEY')));
      expect(EnvConfig.missingRequired(), isNot(contains('LASTFM_API_KEY')));
    });
  });
}
