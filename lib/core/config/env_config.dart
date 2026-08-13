import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Runtime configuration for Everglow.
///
/// Values are supplied at build time via `--dart-define`, or at run time via
/// a locally provided `.env` file. Khent and Clair use real private
/// credentials supplied by CI. Breyan and Octagram are intentionally public
/// cinema-only profiles, so their credentials and the four fixed passcodes
/// are committed as source-level fallbacks.
class EnvConfig {
  static const Map<String, String> _compileTimeEnv = {
    'CLAIR_EMAIL': String.fromEnvironment('CLAIR_EMAIL'),
    'CLAIR_PASSWORD': String.fromEnvironment('CLAIR_PASSWORD'),
    'KHENT_EMAIL': String.fromEnvironment('KHENT_EMAIL'),
    'KHENT_PASSWORD': String.fromEnvironment('KHENT_PASSWORD'),
    'BREYAN_EMAIL': String.fromEnvironment('BREYAN_EMAIL'),
    'BREYAN_PASSWORD': String.fromEnvironment('BREYAN_PASSWORD'),
    'OCTAGRAM_EMAIL': String.fromEnvironment('OCTAGRAM_EMAIL'),
    'OCTAGRAM_PASSWORD': String.fromEnvironment('OCTAGRAM_PASSWORD'),
    'CLAIR_PASSCODE': String.fromEnvironment('CLAIR_PASSCODE'),
    'KHENT_PASSCODE': String.fromEnvironment('KHENT_PASSCODE'),
    'BREYAN_PASSCODE': String.fromEnvironment('BREYAN_PASSCODE'),
    'OCTAGRAM_PASSCODE': String.fromEnvironment('OCTAGRAM_PASSCODE'),
    'TMDB_API_KEY': String.fromEnvironment('TMDB_API_KEY'),
    'LASTFM_API_KEY': String.fromEnvironment('LASTFM_API_KEY'),
    'JELLYFIN_API_KEY': String.fromEnvironment('JELLYFIN_API_KEY'),
    'FCM_VAPID_KEY': String.fromEnvironment('FCM_VAPID_KEY'),
  };

  static String _from(String name, {String fallback = ''}) {
    final fromEnv = _compileTimeEnv[name] ?? '';
    if (fromEnv.isNotEmpty) return fromEnv;
    try {
      final val = dotenv.env[name];
      if (val != null && val.isNotEmpty) return val;
    } catch (_) {
      // dotenv may not be initialized in tests or early bootstrap; the
      // fallback below is the intended behavior in that case.
    }
    return fallback;
  }

  static String get clairEmail => _from('CLAIR_EMAIL');
  static String get clairPassword => _from('CLAIR_PASSWORD');
  static String get khentEmail => _from('KHENT_EMAIL');
  static String get khentPassword => _from('KHENT_PASSWORD');
  static String get breyanEmail =>
      _from('BREYAN_EMAIL', fallback: 'breyan@scrapbook.local');
  static String get breyanPassword =>
      _from('BREYAN_PASSWORD', fallback: '91329132');
  static String get octagramEmail =>
      _from('OCTAGRAM_EMAIL', fallback: 'octagram@scrapbook.local');
  static String get octagramPassword =>
      _from('OCTAGRAM_PASSWORD', fallback: '80808080');

  static String get clairPasscode => _from('CLAIR_PASSCODE', fallback: '0221');
  static String get khentPasscode => _from('KHENT_PASSCODE', fallback: '0938');
  static String get breyanPasscode => _from('BREYAN_PASSCODE', fallback: '9132');
  static String get octagramPasscode =>
      _from('OCTAGRAM_PASSCODE', fallback: '8080');

  static String get tmdbApiKey => _from('TMDB_API_KEY');
  static String get lastfmApiKey => _from('LASTFM_API_KEY');
  static String get jellyfinApiKey => _from('JELLYFIN_API_KEY');
  static String get fcmVapidKey => _from('FCM_VAPID_KEY');

  static bool get hasClairCreds => clairEmail.isNotEmpty && clairPassword.isNotEmpty;
  static bool get hasKhentCreds => khentEmail.isNotEmpty && khentPassword.isNotEmpty;
  static bool get hasBreyanCreds => breyanEmail.isNotEmpty && breyanPassword.isNotEmpty;
  static bool get hasOctagramCreds => octagramEmail.isNotEmpty && octagramPassword.isNotEmpty;
  static bool get hasTmdbKey => tmdbApiKey.isNotEmpty;
  static bool get hasLastfmKey => lastfmApiKey.isNotEmpty;
  static bool get hasJellyfinKey => jellyfinApiKey.isNotEmpty;

  static bool get hasAnyPasscodes =>
      clairPasscode.isNotEmpty ||
      khentPasscode.isNotEmpty ||
      breyanPasscode.isNotEmpty ||
      octagramPasscode.isNotEmpty;

  static List<String> missingRequired() {
    final missing = <String>[];
    if (!hasClairCreds) missing.add('CLAIR_EMAIL / CLAIR_PASSWORD');
    if (!hasKhentCreds) missing.add('KHENT_EMAIL / KHENT_PASSWORD');
    if (!hasBreyanCreds) missing.add('BREYAN_EMAIL / BREYAN_PASSWORD');
    if (!hasOctagramCreds) missing.add('OCTAGRAM_EMAIL / OCTAGRAM_PASSWORD');
    if (!hasTmdbKey) missing.add('TMDB_API_KEY');
    if (!hasLastfmKey) missing.add('LASTFM_API_KEY');
    return missing;
  }
}
