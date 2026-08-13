import 'package:flutter_dotenv/flutter_dotenv.dart';

class EnvConfig {
  static String get clairEmail {
    const fromEnv = String.fromEnvironment('CLAIR_EMAIL', defaultValue: '');
    if (fromEnv.isNotEmpty) return fromEnv;
    if (dotenv.isInitialized) {
      final val = dotenv.env['CLAIR_EMAIL'];
      if (val != null && val.isNotEmpty) return val;
    }
    return 'clairjassen@scrapbook.local';
  }

  static String get clairPassword {
    const fromEnv = String.fromEnvironment('CLAIR_PASSWORD', defaultValue: '');
    if (fromEnv.isNotEmpty) return fromEnv;
    if (dotenv.isInitialized) {
      final val = dotenv.env['CLAIR_PASSWORD'];
      if (val != null && val.isNotEmpty) return val;
    }
    return '111111';
  }

  static String get khentEmail {
    const fromEnv = String.fromEnvironment('KHENT_EMAIL', defaultValue: '');
    if (fromEnv.isNotEmpty) return fromEnv;
    if (dotenv.isInitialized) {
      final val = dotenv.env['KHENT_EMAIL'];
      if (val != null && val.isNotEmpty) return val;
    }
    return 'khentplaysmoba@gmail.com';
  }

  static String get khentPassword {
    const fromEnv = String.fromEnvironment('KHENT_PASSWORD', defaultValue: '');
    if (fromEnv.isNotEmpty) return fromEnv;
    if (dotenv.isInitialized) {
      final val = dotenv.env['KHENT_PASSWORD'];
      if (val != null && val.isNotEmpty) return val;
    }
    return '297864503';
  }

  static String get breyanEmail {
    const fromEnv = String.fromEnvironment('BREYAN_EMAIL', defaultValue: '');
    if (fromEnv.isNotEmpty) return fromEnv;
    if (dotenv.isInitialized) {
      final val = dotenv.env['BREYAN_EMAIL'];
      if (val != null && val.isNotEmpty) return val;
    }
    return 'breyan@scrapbook.local';
  }

  static String get breyanPassword {
    const fromEnv = String.fromEnvironment('BREYAN_PASSWORD', defaultValue: '');
    if (fromEnv.isNotEmpty) return fromEnv;
    if (dotenv.isInitialized) {
      final val = dotenv.env['BREYAN_PASSWORD'];
      if (val != null && val.isNotEmpty) return val;
    }
    return '91329132';
  }

  static String get octagramEmail {
    const fromEnv = String.fromEnvironment('OCTAGRAM_EMAIL', defaultValue: '');
    if (fromEnv.isNotEmpty) return fromEnv;
    if (dotenv.isInitialized) {
      final val = dotenv.env['OCTAGRAM_EMAIL'];
      if (val != null && val.isNotEmpty) return val;
    }
    return 'octagram@scrapbook.local';
  }

  static String get octagramPassword {
    const fromEnv = String.fromEnvironment('OCTAGRAM_PASSWORD', defaultValue: '');
    if (fromEnv.isNotEmpty) return fromEnv;
    if (dotenv.isInitialized) {
      final val = dotenv.env['OCTAGRAM_PASSWORD'];
      if (val != null && val.isNotEmpty) return val;
    }
    return '80808080';
  }

  static String get tmdbApiKey {
    const fromEnv = String.fromEnvironment('TMDB_API_KEY', defaultValue: '');
    if (fromEnv.isNotEmpty) return fromEnv;
    if (dotenv.isInitialized) {
      final val = dotenv.env['TMDB_API_KEY'];
      if (val != null && val.isNotEmpty) return val;
    }
    return 'b41bd33efc365bbdbbad2e31dae8f573';
  }

  static String get lastfmApiKey {
    const fromEnv = String.fromEnvironment('LASTFM_API_KEY', defaultValue: '');
    if (fromEnv.isNotEmpty) return fromEnv;
    if (dotenv.isInitialized) {
      final val = dotenv.env['LASTFM_API_KEY'];
      if (val != null && val.isNotEmpty) return val;
    }
    return 'b2d92f0bec73e334497b7d1a601061da';
  }

  static String get jellyfinApiKey {
    const fromEnv = String.fromEnvironment('JELLYFIN_API_KEY', defaultValue: '');
    if (fromEnv.isNotEmpty) return fromEnv;
    if (dotenv.isInitialized) {
      final val = dotenv.env['JELLYFIN_API_KEY'];
      if (val != null && val.isNotEmpty) return val;
    }
    return '';
  }

  static bool get hasClairCreds => clairEmail.isNotEmpty && clairPassword.isNotEmpty;
  static bool get hasKhentCreds => khentEmail.isNotEmpty && khentPassword.isNotEmpty;
  static bool get hasBreyanCreds => breyanEmail.isNotEmpty && breyanPassword.isNotEmpty;
  static bool get hasOctagramCreds => octagramEmail.isNotEmpty && octagramPassword.isNotEmpty;
  static bool get hasTmdbKey => tmdbApiKey.isNotEmpty;
  static bool get hasJellyfinKey => jellyfinApiKey.isNotEmpty;
  static String get fcmVapidKey {
    const fromEnv = String.fromEnvironment('FCM_VAPID_KEY', defaultValue: '');
    if (fromEnv.isNotEmpty) return fromEnv;
    if (dotenv.isInitialized) {
      final val = dotenv.env['FCM_VAPID_KEY'];
      if (val != null && val.isNotEmpty) return val;
    }
    return '';
  }

  static bool get hasLastfmKey => lastfmApiKey.isNotEmpty;

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
