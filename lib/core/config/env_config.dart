import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Runtime configuration for Everglow.
///
/// Values are supplied at build time via --dart-define, or at run time via
/// a locally provided .env file. Passcodes and account credentials have no
/// literal fallbacks in source code: builds must pass them via --dart-define
/// or .env, or the field is empty and that profile cannot log in. Server
/// stays the only source of truth for Khent/Clair. Breyan/Octagram cinema-only
/// profiles stay client-verified.
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
    'APP_CHECK_WEB_SITE_KEY': String.fromEnvironment('APP_CHECK_WEB_SITE_KEY'),
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

  static String get breyanEmail =>
      _from('BREYAN_EMAIL', fallback: 'breyan@scrapbook.local');
  static String get breyanPassword => _from('BREYAN_PASSWORD');
  static String get octagramEmail =>
      _from('OCTAGRAM_EMAIL', fallback: 'octagram@scrapbook.local');
  static String get octagramPassword => _from('OCTAGRAM_PASSWORD');

  // Khent/Clair passphrases stay server-side in production; these values are
  // only for ignored local .env/dev tooling. Cinema passcodes are client-side
  // because those accounts cannot access couple data.
  static String get clairPasscode => _from('CLAIR_PASSCODE');
  static String get khentPasscode => _from('KHENT_PASSCODE');
  static String get breyanPasscode => _from('BREYAN_PASSCODE');
  static String get octagramPasscode => _from('OCTAGRAM_PASSCODE');

  static String get lastfmUserKhent =>
      _from('LASTFM_USER_KHENT', fallback: 'khentsgdz');
  static String get lastfmUserClair =>
      _from('LASTFM_USER_CLAIR', fallback: 'clairjassen');
  static String get spotifyClientId => _from('SPOTIFY_CLIENT_ID');
  static String get appCheckWebSiteKey => _from('APP_CHECK_WEB_SITE_KEY');

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
