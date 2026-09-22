import 'package:everglow/core/config/env_config.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EnvConfig unconfigured defaults', () {
    setUp(() {
      dotenv.clean();
    });

    tearDown(() {
      dotenv.clean();
    });

    test('passcodes and cinema passwords have no literal source fallbacks', () {
      expect(EnvConfig.clairPasscode, isEmpty);
      expect(EnvConfig.khentPasscode, isEmpty);
      expect(EnvConfig.breyanPasscode, isEmpty);
      expect(EnvConfig.octagramPasscode, isEmpty);
      expect(EnvConfig.breyanPassword, isEmpty);
      expect(EnvConfig.octagramPassword, isEmpty);
    });

    test('has* flags reflect unconfigured state without env defines', () {
      expect(EnvConfig.hasBreyanCreds, isFalse);
      expect(EnvConfig.hasOctagramCreds, isFalse);
      expect(EnvConfig.hasAnyPasscodes, isFalse);
    });

    test('missingRequired reports unconfigured cinema credentials', () {
      final missing = EnvConfig.missingRequired();
      expect(
        missing,
        containsAll([
          'BREYAN_EMAIL / BREYAN_PASSWORD',
          'OCTAGRAM_EMAIL / OCTAGRAM_PASSWORD',
        ]),
      );
    });

    test('public identifiers keep their defaults', () {
      expect(EnvConfig.fcmVapidKey, isNotEmpty);
      expect(EnvConfig.lastfmUserKhent, 'khentsgdz');
      expect(EnvConfig.lastfmUserClair, 'clairjassen');
      expect(EnvConfig.breyanEmail, 'breyan@scrapbook.local');
      expect(EnvConfig.octagramEmail, 'octagram@scrapbook.local');
    });

    test('server-only credentials are never exposed in client config', () {
      expect(EnvConfig.missingRequired(), isNot(contains('TMDB_API_KEY')));
      expect(EnvConfig.missingRequired(), isNot(contains('LASTFM_API_KEY')));
    });
  });

  group('EnvConfig with environment values provided', () {
    setUp(() {
      dotenv.loadFromString(
        envString: '''
CLAIR_PASSCODE=1111
KHENT_PASSCODE=2222
BREYAN_PASSCODE=3333
OCTAGRAM_PASSCODE=4444
BREYAN_PASSWORD=breyan_secret
OCTAGRAM_PASSWORD=octagram_secret
''',
      );
    });

    tearDown(() {
      dotenv.clean();
    });

    test('picks up configured passcodes and credentials', () {
      expect(EnvConfig.clairPasscode, '1111');
      expect(EnvConfig.khentPasscode, '2222');
      expect(EnvConfig.breyanPasscode, '3333');
      expect(EnvConfig.octagramPasscode, '4444');
      expect(EnvConfig.breyanPassword, 'breyan_secret');
      expect(EnvConfig.octagramPassword, 'octagram_secret');
    });

    test('has* flags and missingRequired reflect configured state', () {
      expect(EnvConfig.hasBreyanCreds, isTrue);
      expect(EnvConfig.hasOctagramCreds, isTrue);
      expect(EnvConfig.hasAnyPasscodes, isTrue);
      expect(EnvConfig.missingRequired(), isEmpty);
    });
  });
}
