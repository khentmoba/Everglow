import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Runtime configuration for Everglow.
///
/// Values are supplied at build time via --dart-define, or at run time via
/// a locally provided .env file. The four gateway passcodes are documented
/// in AGENTS.md, and Breyan/Octagram are intentionally public cinema-only
/// profiles, so those values keep source-level fallbacks. Khent/Clair email
/// and password credentials are never committed.
class EnvConfig {
  static const Map<String, String> _compileTimeEnv = {
    'BREYAN_EMAIL': String.fromEnvironment('BREYAN_EMAIL'),
    'BREYAN_PASSWORD': String.fromEnvironment('BREYAN_PASSWORD'),
    'OCTAGRAM_EMAIL': String.fromEnvironment('OCTAGRAM_EMAIL'),
    'OCTAGRAM_PASSWORD': String.fromEnvironment('OCTAGRAM_PASSWORD'),
    'CLAIR_PASSCODE': String.fromEnvironment('CLAIR_PASSCODE'),
    'KHENT_PASSCODE': String.fromEnvironment('KHENT_PASSCODE'),
    'BREYAN_PASSCODE': String.fromEnvironment('BREYAN_PASSCODE'),
    'OCTAGRAM_PASSCODE': String.fromEnvironment('OCTAGRAM_PASSCODE'),
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
    } catch (_) {
    }
    return fallback;
  }

  static String get breyanEmail =>
      _from('BREYAN_EMAIL', fallback: 'breyan@scrapbook.local');
  static String get breyanPassword =>
      _from('BREYAN_PASSWORD', fallback: '91329132');
  static String get octagramEmail =>
      _from('OCTAGRAM_EMAIL', fallback: 'octagram@scrapbook.local');
  static String get octagramPassword =>
      _from('OCTAGRAM_PASSWORD', fallback: '80808080');

  // Gateway passcodes: server-verified in prod when possible, but keep
  // client fallbacks so offline/debug and server-outage don't brick login.
  // 0221/0938 are documented in AGENTS.md and not considered secrets.
  static String get clairPasscode =>
      _from('CLAIR_PASSCODE', fallback: '0221');
  static String get khentPasscode =>
      _from('KHENT_PASSCODE', fallback: '0938');
  static String get breyanPasscode =>
      _from('BREYAN_PASSCODE', fallback: '9132');
  static String get octagramPasscode =>
      _from('OCTAGRAM_PASSCODE', fallback: '8080');

  static String get lastfmUserKhent =>
      _from('LASTFM_USER_KHENT', fallback: 'khentsgdz');
  static String get lastfmUserClair =>
      _from('LASTFM_USER_CLAIR', fallback: 'clairjassen');
  static String get spotifyClientId => _from('SPOTIFY_CLIENT_ID');

  static const String _kFcmVapidKey =
      'BL2l-ngjWKYYXNK5QKHRcLt4zUyHq-3wTgY5NO0MOcGEoI03Eh3A3Kk2us_hQdN4tXyOO4A6ldQ1T5L7DLTSrT0';
  static String get fcmVapidKey =>
      _from('FCM_VAPID_KEY', fallback: _kFcmVapidKey);

  static bool get hasBreyanCreds =>
      breyanEmail.isNotEmpty && breyanPassword.isNotEmpty;
  static bool get hasOctagramCreds =>
      octagramEmail.isNotEmpty && octagramPassword.isNotEmpty;
  static bool get hasSpotifyClientId => spotifyClientId.isNotEmpty;

  static bool get hasAnyPasscodes =>
      clairPasscode.isNotEmpty ||
      khentPasscode.isNotEmpty ||
      breyanPasscode.isNotEmpty ||
      octagramPasscode.isNotEmpty;

  static List<String> missingRequired() {
    final missing = <String>[];
    if (!hasBreyanCreds) missing.add('BREYAN_EMAIL / BREYAN_PASSWORD');
    if (!hasOctagramCreds) missing.add('OCTAGRAM_EMAIL / OCTAGRAM_PASSWORD');
    return missing;
  }
}
