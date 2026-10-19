import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Public client configuration only. All profile codes and account
/// credentials are verified by the server and must never enter a web build.
class EnvConfig {
  static const Map<String, String> _compileTimeEnv = {
    'LASTFM_USER_KHENT': String.fromEnvironment('LASTFM_USER_KHENT'),
    'LASTFM_USER_CLAIR': String.fromEnvironment('LASTFM_USER_CLAIR'),
    'FCM_VAPID_KEY': String.fromEnvironment('FCM_VAPID_KEY'),
    'SPOTIFY_CLIENT_ID': String.fromEnvironment('SPOTIFY_CLIENT_ID'),
  };

  static String _from(String name, {String fallback = ''}) {
    final fromEnv = (_compileTimeEnv[name] ?? '').trim();
    if (fromEnv.isNotEmpty) return fromEnv;
    try {
      final val = dotenv.env[name]?.trim();
      if (val != null && val.isNotEmpty) return val;
    } catch (_) {}
    return fallback;
  }

  static String get lastfmUserKhent =>
      _from('LASTFM_USER_KHENT', fallback: 'khentsgdz');
  static String get lastfmUserClair =>
      _from('LASTFM_USER_CLAIR', fallback: 'clairjassen');
  static String get spotifyClientId => _from('SPOTIFY_CLIENT_ID');

  static const String _kFcmVapidKey =
      'BL2l-ngjWKYYXNK5QKHRcLt4zUyHq-3wTgY5NO0MOcGEoI03Eh3A3Kk2us_hQdN4tXyOO4A6ldQ1T5L7DLTSrT0';
  static String get fcmVapidKey =>
      _from('FCM_VAPID_KEY', fallback: _kFcmVapidKey);

  static bool get hasSpotifyClientId => spotifyClientId.isNotEmpty;
}
