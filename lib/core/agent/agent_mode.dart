import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/logger.dart';

/// Central controller for Agent Mode in Everglow.
///
/// Agent Mode enables automated agents (and local development workflows) to:
/// 1. Directly access any route without getting stuck at the password gate (`/`).
/// 2. Experience authentic, populated UI states using isolated mock fixtures
///    (safely protecting real couple data and photos from public PR proofs).
/// 3. Toggle between user profiles ('khentsgdz', 'clairjassen', 'breyan' / cinema).
/// 4. Interact with a floating Agent HUD toolbar to jump between core surfaces.
class AgentMode {
  AgentMode._();

  /// Map of convenient route aliases for direct agent navigation.
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
    'watch-party': '/cinema?tab=4',
    'watchparty': '/cinema?tab=4',
  };

  /// Whether Agent Mode is currently enabled.
  static final ValueNotifier<bool> isActive = ValueNotifier<bool>(false);

  /// Currently active simulated profile:
  /// - `khentsgdz`: Full couple access (Khent's perspective)
  /// - `clairjassen`: Full couple access (Clair's perspective)
  /// - `breyan`: Cinema-only guest profile
  static final ValueNotifier<String> activeProfile =
      ValueNotifier<String>('khentsgdz');

  /// Whether services should feed privacy-safe mock demo fixtures instead of
  /// hitting real Firestore / Firebase Storage.
  static final ValueNotifier<bool> useDemoData = ValueNotifier<bool>(true);

  /// Whether the floating Agent HUD should be visible on screen.
  static final ValueNotifier<bool> showHud = ValueNotifier<bool>(true);

  /// Whether the floating Agent HUD is minimized into a small pill.
  static final ValueNotifier<bool> hudCollapsed = ValueNotifier<bool>(false);

  static const String _prefActiveKey = 'everglow_agent_mode_active';
  static const String _prefProfileKey = 'everglow_agent_mode_profile';

  /// Whether the current runtime is local development (debug mode or localhost).
  static bool get isLocalDev {
    if (kDebugMode) return true;
    if (kIsWeb) {
      final host = Uri.base.host;
      return host == 'localhost' || host == '127.0.0.1' || host == '0.0.0.0';
    }
    return false;
  }

  /// Whether agent mode is compiled in via dart-define `--dart-define=AGENT_MODE=true`.
  static const bool isCompiledIn = bool.fromEnvironment(
    'AGENT_MODE',
    defaultValue: false,
  );

  /// Resolves profile from query parameter value.
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

  /// Initializes AgentMode on app boot from URL parameters and preferences.
  static Future<void> init({Map<String, String>? queryParameters}) async {
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

  /// Activates Agent Mode with the specified profile.
  static void enable({String profile = 'khentsgdz'}) {
    isActive.value = true;
    activeProfile.value = profile;
    Logger.i('[AgentMode] Activated with profile: $profile');
    _persist();
  }

  /// Switches active profile while remaining in Agent Mode.
  static void switchProfile(String profile) {
    activeProfile.value = profile;
    Logger.i('[AgentMode] Switched profile to: $profile');
    _persist();
  }

  /// Deactivates Agent Mode.
  static void disable() {
    isActive.value = false;
    Logger.i('[AgentMode] Deactivated');
    _persist();
  }

  static Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefActiveKey, isActive.value);
      await prefs.setString(_prefProfileKey, activeProfile.value);
    } catch (e, st) {
      Logger.e('AgentMode: failed to persist state', error: e, stackTrace: st);
    }
  }
}
