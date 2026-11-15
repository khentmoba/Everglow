import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'app_typography.dart';

class SectionFonts {
  static Future<void>? _reading;
  static Future<void>? _anime;
  static final Set<int> _warmedRunes = <int>{};

  static Future<void> reading() => _reading ??=
      _load('DM Sans', [
        'DMSans-Regular.ttf',
        'DMSans-Medium.ttf',
        'DMSans-SemiBold.ttf',
        'DMSans-Bold.ttf',
      ]).catchError((Object error, StackTrace stack) {
        _reading = null;
        Error.throwWithStackTrace(error, stack);
      });

  static Future<void> anime() => _anime ??=
      Future.wait([
        reading(),
        _load('Bebas Neue', ['BebasNeue-Regular.ttf']),
      ]).then<void>((_) {}).catchError((Object error, StackTrace stack) {
        _anime = null;
        Error.throwWithStackTrace(error, stack);
      });

  static void warmFallbackGlyphs(
    Iterable<String> texts, {
    @visibleForTesting bool force = false,
  }) {
    if (!kIsWeb && !force) return;
    final unseen = <int>[];
    for (final text in texts) {
      if (text.isEmpty) continue;
      for (final rune in text.runes) {
        if (rune > 0x7F && _warmedRunes.add(rune)) {
          unseen.add(rune);
          if (unseen.length >= 256) break;
        }
      }
      if (unseen.length >= 256) break;
    }
    if (unseen.isEmpty) return;
    final sample = String.fromCharCodes(unseen);
    SchedulerBinding.instance.addPostFrameCallback((_) {
      final painter = TextPainter(
        text: TextSpan(
          text: sample,
          style: const TextStyle(
            fontSize: 12,
            fontFamily: AppTypography.body,
            fontFamilyFallback: AppTypography.fontFallback,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.dispose();
    });
  }

  @visibleForTesting
  static int get warmedGlyphCountForTesting => _warmedRunes.length;

  @visibleForTesting
  static void resetWarmedGlyphsForTesting() => _warmedRunes.clear();

  static Future<void> _load(String family, List<String> files) {
    final loader = FontLoader(family);
    for (final file in files) {
      loader.addFont(rootBundle.load('assets/google_fonts/$file'));
    }
    return loader.load();
  }
}
