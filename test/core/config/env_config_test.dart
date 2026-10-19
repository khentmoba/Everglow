import 'package:everglow/core/config/env_config.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(dotenv.clean);
  tearDown(dotenv.clean);

  test('public identifiers keep their defaults', () {
    expect(EnvConfig.fcmVapidKey, isNotEmpty);
    expect(EnvConfig.lastfmUserKhent, 'khentsgdz');
    expect(EnvConfig.lastfmUserClair, 'clairjassen');
    expect(EnvConfig.hasSpotifyClientId, isFalse);
  });

  test('public configuration accepts local overrides', () {
    dotenv.loadFromString(
      envString:
          'LASTFM_USER_KHENT=demo-khent\n'
          'LASTFM_USER_CLAIR=demo-clair\nSPOTIFY_CLIENT_ID=public-id\n'
          'FCM_VAPID_KEY=public-vapid',
    );
    expect(EnvConfig.lastfmUserKhent, 'demo-khent');
    expect(EnvConfig.lastfmUserClair, 'demo-clair');
    expect(EnvConfig.spotifyClientId, 'public-id');
    expect(EnvConfig.hasSpotifyClientId, isTrue);
    expect(EnvConfig.fcmVapidKey, 'public-vapid');
  });
}
