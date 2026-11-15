import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/logger.dart';

class AgentMode {
  AgentMode._();

  static const Map<String, String> routeAliases = {
    'cinema': '/cinema',
    'anime': '/anime',
    'manga': '/manga',
    'mangacelestia': '/manga',
    'books': '/books',
    'bibliotheca': '/books',
    'dashboard': '/dashboard',
    'home': '/dashboard',
    'sanctuary': '/sanctuary',
    'chat': '/sanctuary',
    'gallery': '/gallery',
    'journal': '/journal',
    'tonight': '/tonight',
    'calendar': '/calendar',
    'garden': '/garden',
    'bloom': '/garden',
    'starlight': '/starlight',
    'play': '/play-zone',
    'playzone': '/play-zone',
    'play-zone': '/play-zone',
    'arcade': '/play-zone',
    'academy': '/academy',
    'trip-kit': '/trips',
    'tripkit': '/trips',
    'canvas': '/canvas',
    'bucket-list': '/bucket-list',
    'bucketlist': '/bucket-list',
    'money': '/money',
    'jukebox': '/jukebox',
    'music': '/jukebox',
    'watch-party': '/watch-party',
    'watchparty': '/watch-party',
  };

  static final ValueNotifier<bool> isActive = ValueNotifier<bool>(false);

  static final ValueNotifier<String> activeProfile = ValueNotifier<String>(
    'khentsgdz',
  );

  static final ValueNotifier<bool> useDemoData = ValueNotifier<bool>(true);

  static final ValueNotifier<bool> showHud = ValueNotifier<bool>(true);

  static final ValueNotifier<bool> hudCollapsed = ValueNotifier<bool>(false);

  static const String _prefActiveKey = 'everglow_agent_mode_active';
  static const String _prefProfileKey = 'everglow_agent_mode_profile';
  static Future<void> _pendingPersist = Future<void>.value();

  static bool get isLocalDev {
    if (kIsWeb && isLocalHost(Uri.base.host)) return true;
    return kDebugMode;
  }

  static bool isProductionHost(String host) =>
      host == 'everglow-1c6db.web.app' ||
      host == 'everglow-1c6db.firebaseapp.com';

  static bool isLocalHost(String host) =>
      host == 'localhost' || host == '127.0.0.1' || host == '0.0.0.0';

  static bool get canActivate => !kIsWeb || !isProductionHost(Uri.base.host);

  static const bool isCompiledIn = bool.fromEnvironment(
    'AGENT_MODE',
    defaultValue: false,
  );

  static String parseProfile(String? value) {
    if (value == null || value.isEmpty || value == '1' || value == 'true') {
      return 'khentsgdz';
    }
    final lower = value.toLowerCase().trim();
    if (lower == 'clair' || lower == 'clairjassen') return 'clairjassen';
    if (lower == 'cinema' || lower == 'breyan' || lower == 'guest') {
      return 'breyan';
    }
    return 'khentsgdz';
  }

  static Future<void> init({
    Map<String, String>? queryParameters,
    String? host,
  }) async {
    if (isProductionHost(host ?? (kIsWeb ? Uri.base.host : ''))) {
      isActive.value = false;
      await clearPersistedState();
      return;
    }
    final params = queryParameters ?? Uri.base.queryParameters;
    final agentParam = params['agent'] ?? params['demo'];

    if (agentParam != null) {
      final profile = parseProfile(agentParam);
      enable(profile: profile);
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final savedActive = prefs.getBool(_prefActiveKey) ?? false;
      final savedProfile = prefs.getString(_prefProfileKey) ?? 'khentsgdz';
      if (savedActive || isCompiledIn) {
        isActive.value = true;
        activeProfile.value = savedProfile;
      }
    } catch (e) {
      Logger.w('[AgentMode] Failed to read saved state: $e');
    }
  }

  static bool enable({String profile = 'khentsgdz', String? host}) {
    if (isProductionHost(host ?? (kIsWeb ? Uri.base.host : ''))) return false;
    isActive.value = true;
    activeProfile.value = profile;
    Logger.i('[AgentMode] Activated with profile: $profile');
    _persist();
    return true;
  }

  static void switchProfile(String profile) {
    activeProfile.value = profile;
    Logger.i('[AgentMode] Switched profile to: $profile');
    _persist();
  }

  static void disable() {
    isActive.value = false;
    Logger.i('[AgentMode] Deactivated');
    _persist();
  }

  static Future<void> clearPersistedState() async {
    isActive.value = false;
    await _pendingPersist;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefActiveKey);
      await prefs.remove(_prefProfileKey);
    } catch (e, st) {
      Logger.e(
        'AgentMode: failed to clear saved state',
        error: e,
        stackTrace: st,
      );
    }
  }

  static Future<void> _persist() {
    _pendingPersist = _pendingPersist.then((_) async {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_prefActiveKey, isActive.value);
        await prefs.setString(_prefProfileKey, activeProfile.value);
      } catch (e, st) {
        Logger.e(
          'AgentMode: failed to persist state',
          error: e,
          stackTrace: st,
        );
      }
    });
    return _pendingPersist;
  }
}
