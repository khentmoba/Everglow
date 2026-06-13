import 'package:flutter_dotenv/flutter_dotenv.dart';

class EnvConfig {
  static String get clairEmail {
    const fromEnv = String.fromEnvironment('CLAIR_EMAIL', defaultValue: '');
    if (fromEnv.isNotEmpty) return fromEnv;
    if (dotenv.isInitialized) {
      return dotenv.env['CLAIR_EMAIL'] ?? '';
    }
    return '';
  }

  static String get clairPassword {
    const fromEnv = String.fromEnvironment('CLAIR_PASSWORD', defaultValue: '');
    if (fromEnv.isNotEmpty) return fromEnv;
    if (dotenv.isInitialized) {
      return dotenv.env['CLAIR_PASSWORD'] ?? '';
    }
    return '';
  }

  static String get khentEmail {
    const fromEnv = String.fromEnvironment('KHENT_EMAIL', defaultValue: '');
    if (fromEnv.isNotEmpty) return fromEnv;
    if (dotenv.isInitialized) {
      return dotenv.env['KHENT_EMAIL'] ?? '';
    }
    return '';
  }

  static String get khentPassword {
    const fromEnv = String.fromEnvironment('KHENT_PASSWORD', defaultValue: '');
    if (fromEnv.isNotEmpty) return fromEnv;
    if (dotenv.isInitialized) {
      return dotenv.env['KHENT_PASSWORD'] ?? '';
    }
    return '';
  }

  static String get tmdbApiKey {
    const fromEnv = String.fromEnvironment('TMDB_API_KEY', defaultValue: '');
    if (fromEnv.isNotEmpty) return fromEnv;
    if (dotenv.isInitialized) {
      return dotenv.env['TMDB_API_KEY'] ?? '';
    }
    return '';
  }

  static String get lastfmApiKey {
    const fromEnv = String.fromEnvironment('LASTFM_API_KEY', defaultValue: '');
    if (fromEnv.isNotEmpty) return fromEnv;
    if (dotenv.isInitialized) {
      return dotenv.env['LASTFM_API_KEY'] ?? '';
    }
    return '';
  }

  static bool get hasClairCreds => clairEmail.isNotEmpty && clairPassword.isNotEmpty;
  static bool get hasKhentCreds => khentEmail.isNotEmpty && khentPassword.isNotEmpty;
  static bool get hasTmdbKey => tmdbApiKey.isNotEmpty;
  static bool get hasLastfmKey => lastfmApiKey.isNotEmpty;

  static List<String> missingRequired() {
    final missing = <String>[];
    if (!hasClairCreds) missing.add('CLAIR_EMAIL / CLAIR_PASSWORD');
    if (!hasKhentCreds) missing.add('KHENT_EMAIL / KHENT_PASSWORD');
    if (!hasTmdbKey) missing.add('TMDB_API_KEY');
    if (!hasLastfmKey) missing.add('LASTFM_API_KEY');
    return missing;
  }
}

