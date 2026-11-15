import 'dart:io';

import '_io.dart';

Future<void> main() async {
  final failures = <String>[];

  final mangaDir = Directory('lib/features/manga');
  if (!await mangaDir.exists()) {
    stderr.writeln('[no-ads] lib/features/manga/ not found; run from repo root.');
    exit(2);
  }

  final bannedSubstrings = [
    'google_mobile_ads',
    'admob',
    'adsense',
    'doubleclick',
    'googlesyndication',
    'hide_ad',
    'hidead',
    'hide ads',
  ];

  final bannedWords = RegExp(
    r'\b(InterstitialAd|RewardedAd|BannerAd|NativeAd|AppOpenAd|'
    r'WebView|InAppWebView|flutter_inappwebview|webview_flutter)\b',
  );

  await for (final e in mangaDir.list(recursive: true)) {
    if (e is! File || !e.path.endsWith('.dart')) continue;
    final src = await readTolerant(e);
    final lower = src.toLowerCase();
    for (final marker in bannedSubstrings) {
      if (lower.contains(marker)) {
        failures.add('${e.path}: banned ad marker "$marker".');
      }
    }
    for (final m in bannedWords.allMatches(src)) {
      failures.add('${e.path}: banned ad/webview marker "${m.group(0)}".');
    }
  }

  final pubspec = File('pubspec.yaml');
  if (await pubspec.exists()) {
    final src = await readTolerant(pubspec);
    for (final marker in ['google_mobile_ads', 'admob', 'flutter_ads']) {
      if (src.toLowerCase().contains(marker)) {
        failures.add('pubspec.yaml: banned ad dependency "$marker".');
      }
    }
  }

  if (failures.isEmpty) {
    stdout.writeln('[no-ads] OK: manga stays ad-free (no SDKs, widgets, or webviews).');
    return;
  }
  stderr.writeln('[no-ads] FAIL (${failures.length}):');
  for (final f in failures) {
    stderr.writeln('  - $f');
  }
  exit(1);
}
