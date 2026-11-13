import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_colors.dart';
import '../utils/logger.dart';
import 'tv_detector.dart';

/// Central state and styling helpers for TV-friendly browsing and remote navigation.
///
/// Automatically activates on Smart TV browsers (Tizen, webOS, Android TV, Fire TV, etc.)
/// or when requested via URL query (`?tv=1`, `?mode=tv`), and supports user toggle.
class TvMode {
  TvMode._();

  static const String _prefKey = 'tv_mode_enabled';

  /// Reactive notifier for active TV mode.
  static final ValueNotifier<bool> isTvMode = ValueNotifier<bool>(false);

  static bool _initialized = false;

  /// Initializes TV mode from URL override, persistent preference, or browser user agent.
  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    try {
      final urlOverride = TvDetector.detectUrlOverride();
      if (urlOverride != null) {
        isTvMode.value = urlOverride;
        return;
      }
      final prefs = await SharedPreferences.getInstance();
      final hasStored = prefs.containsKey(_prefKey);
      if (hasStored) {
        isTvMode.value = prefs.getBool(_prefKey) ?? false;
      } else {
        final isTv = TvDetector.detectTvBrowser();
        isTvMode.value = isTv;
      }
    } catch (e) {
      Logger.e('TvMode init failed', error: e);
      isTvMode.value = TvDetector.detectTvBrowser();
    }
  }

  /// Detects Smart TV / Android TV browsers from [userAgent] and touch capability.
  ///
  /// Android TV browsers often omit "TV" from their UA string, but unlike
  /// phones and tablets they report `maxTouchPoints == 0` in landscape.
  static bool isTvUserAgent(
    String userAgent, {
    int maxTouchPoints = 1,
    bool isLandscape = false,
  }) {
    final ua = userAgent.toLowerCase();
    const tvKeywords = [
      'tv',
      'smarttv',
      'googletv',
      'android tv',
      'leanback',
      'shield',
      'mibox',
      'mi box',
      'chromecast',
      'nexus player',
      'adt-',
      'tvbro',
      'tv bro',
      'odin',
      'jiopages',
      'tizen',
      'webos',
      'web0s',
      'viera',
      'bravia',
      'hbbtv',
      'netcast',
      'apple tv',
      'appletv',
      'roku',
      'crkey',
      'aft', // Amazon Fire TV (AFTM, AFTT, etc.)
      'pov_tv',
    ];
    for (final kw in tvKeywords) {
      if (ua.contains(kw)) return true;
    }
    if (ua.contains('android') &&
        !ua.contains('mobile') &&
        maxTouchPoints == 0 &&
        isLandscape) {
      return true;
    }
    return false;
  }

  /// Explicitly enables or disables TV mode, persisting the preference.
  static Future<void> setTvMode(bool enabled) async {
    isTvMode.value = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKey, enabled);
    } catch (e) {
      Logger.e('Failed to persist tv_mode preference', error: e);
    }
  }

  /// Toggles TV mode on or off.
  static Future<void> toggle() => setTvMode(!isTvMode.value);

  /// Standard activation shortcuts for TV remotes (D-pad Center / Select / Enter / Space).
  static const Map<ShortcutActivator, Intent> activateShortcuts = {
    SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
    SingleActivator(LogicalKeyboardKey.select): ActivateIntent(),
    SingleActivator(LogicalKeyboardKey.numpadEnter): ActivateIntent(),
    SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
    SingleActivator(LogicalKeyboardKey.gameButtonA): ActivateIntent(),
  };

  /// Scrolls the nearest scrollable ancestor so [context] is centered on TV.
  static void ensureFocusedVisible(BuildContext context) {
    if (!isTvMode.value) return;
    if (!context.mounted) return;
    if (Scrollable.maybeOf(context) == null) return;
    Scrollable.ensureVisible(
      context,
      alignment: 0.5,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  /// True if [key] acts as a primary selection / OK action on TV remotes or keyboards.
  static bool isSelectKey(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.space ||
        key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.gameButtonA;
  }

  /// True if [key] acts as a Back / Exit / Cancel action on TV remotes or keyboards.
  static bool isBackKey(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.backspace ||
        key == LogicalKeyboardKey.delete ||
        key == LogicalKeyboardKey.goBack ||
        key == LogicalKeyboardKey.browserBack ||
        key == LogicalKeyboardKey.gameButtonB;
  }

  /// Extracts a digit string ('0'..'9') if [key] is a number key on a TV remote or keyboard.
  static String? digitFromKey(LogicalKeyboardKey key) {
    // 1. Direct logical keys
    if (key == LogicalKeyboardKey.digit0 || key == LogicalKeyboardKey.numpad0) {
      return '0';
    }
    if (key == LogicalKeyboardKey.digit1 || key == LogicalKeyboardKey.numpad1) {
      return '1';
    }
    if (key == LogicalKeyboardKey.digit2 || key == LogicalKeyboardKey.numpad2) {
      return '2';
    }
    if (key == LogicalKeyboardKey.digit3 || key == LogicalKeyboardKey.numpad3) {
      return '3';
    }
    if (key == LogicalKeyboardKey.digit4 || key == LogicalKeyboardKey.numpad4) {
      return '4';
    }
    if (key == LogicalKeyboardKey.digit5 || key == LogicalKeyboardKey.numpad5) {
      return '5';
    }
    if (key == LogicalKeyboardKey.digit6 || key == LogicalKeyboardKey.numpad6) {
      return '6';
    }
    if (key == LogicalKeyboardKey.digit7 || key == LogicalKeyboardKey.numpad7) {
      return '7';
    }
    if (key == LogicalKeyboardKey.digit8 || key == LogicalKeyboardKey.numpad8) {
      return '8';
    }
    if (key == LogicalKeyboardKey.digit9 || key == LogicalKeyboardKey.numpad9) {
      return '9';
    }

    // 2. ASCII keyId check (0x30 to 0x39 corresponds to '0' to '9')
    if (key.keyId >= 0x30 && key.keyId <= 0x39) {
      return String.fromCharCode(key.keyId);
    }

    // 3. Fallback to single-digit keyLabel
    final label = key.keyLabel;
    if (label.length == 1 && RegExp(r'^[0-9]$').hasMatch(label)) {
      return label;
    }

    return null;
  }

  /// High-visibility focus border for 10-foot TV viewing.
  static Border focusBorder({
    Color accent = AppColors.auroraGold,
    double width = 3.0,
  }) {
    return Border.all(color: accent, width: width);
  }

  /// High-visibility glowing focus shadows for 10-foot TV viewing.
  static List<BoxShadow> focusShadows({
    Color accent = AppColors.auroraGold,
    double blurRadius = 18.0,
    double spreadRadius = 2.0,
  }) {
    return [
      BoxShadow(
        color: accent.withValues(alpha: 0.65),
        blurRadius: blurRadius,
        spreadRadius: spreadRadius,
      ),
      const BoxShadow(
        color: AppColors.scrimStrong,
        blurRadius: 10,
        offset: Offset(0, 4),
      ),
    ];
  }
}
