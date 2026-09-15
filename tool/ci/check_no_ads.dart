// Zero-ads guard for MangaCelestia: Clair reads with absolutely no ads,
// ever. MangaKatana itself is ad-funded (Hide Ads buttons, ad scripts,
// popups), but we copy only its layout and reader behavior — never its
// ad machinery.
//
// Rule: lib/features/manga/ must not contain ad SDKs, ad widgets, the
// site's Hide-Ads flow, or WebViews that would execute scraped site
// scripts. The Katana path parses proxied HTML as strings (covers,
// chapters, text) and never renders it, so site ads can't reach Clair.
// pubspec.yaml must not gain ad dependencies either.
//
// Usage: dart tool/ci/check_no_ads.dart
import 'dart:convert';
import 'dart:io';

// Lenient read; all markers we look for are ASCII.
Future<String> readTolerant(File f) =>
    f.readAsBytes().then((b) => utf8.decode(b, allowMalformed: true));

Future<void> main() async {
  final failures = <String>[];

  final mangaDir = Directory('lib/features/manga');
  if (!await mangaDir.exists()) {
    stderr.writeln('[no-ads] lib/features/manga/ not found; run from repo root.');
    exit(2);
  }

  // Case-insensitive substring markers for ad SDKs and networks.
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

  // Word-boundary markers for ad widget classes and webviews.
  // (Plain substrings would false-positive on e.g. `_showAddDialog`.)
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
