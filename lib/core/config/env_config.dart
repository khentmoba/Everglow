class EnvConfig {
  static const String clairEmail = String.fromEnvironment(
    'CLAIR_EMAIL',
    defaultValue: '',
  );

  static const String clairPassword = String.fromEnvironment(
    'CLAIR_PASSWORD',
    defaultValue: '',
  );

  static const String khentEmail = String.fromEnvironment(
    'KHENT_EMAIL',
    defaultValue: '',
  );

  static const String khentPassword = String.fromEnvironment(
    'KHENT_PASSWORD',
    defaultValue: '',
  );

  static const String tmdbApiKey = String.fromEnvironment(
    'TMDB_API_KEY',
    defaultValue: '',
  );

  static const String lastfmApiKey = String.fromEnvironment(
    'LASTFM_API_KEY',
    defaultValue: '',
  );

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
