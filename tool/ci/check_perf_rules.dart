// Perf-rule guard: no per-frame rebuilds driven by an animation callback.
//
// The rule is in docs/PERF_NOTES.md under "Animation rules":
//
//   > No `setState` in ticker callbacks — use `ValueNotifier`/`AnimatedBuilder`.
//
// Flutter Web keeps no rendered layers, so build and raster share one thread,
// and a `setState` driven by a 60fps callback rebuilds the enclosing widget 60
// times a second to change one pixel. Until now nothing stopped it: the rule
// was prose.
//
// Precision matters more than breadth here. A first cut flagged every
// `setState` within a dozen lines of an `addListener` and produced 17 hits on a
// clean tree — all of them legitimate: a `FocusNode` listener, a
// `TextEditingController` listener, and `Timer.periodic` at 2200ms and 30s.
// A guard that cries wolf on working code gets ignored or deleted, so this
// version only fires on shapes that really are frame-rate:
//
//   * `setState` inside a callback on a known AnimationController/Ticker
//     (including the `..addListener(` cascade form),
//   * `setState` inside a `Ticker(...)` callback,
//   * `setState` inside `Timer.periodic(...)` whose period is <= 20ms.
//
// A genuine case can be waived with `// ci:perf-ticker-setstate: <reason>`,
// and every waiver is printed so it cannot rot silently.
//
// Usage: dart tool/ci/check_perf_rules.dart
import 'dart:io';

import '_io.dart';

/// A timer at or below this period is treated as a frame driver. Above it, a
/// periodic `setState` is just a clock (the presence indicator runs at 30s, the
/// rotating phrase at 2.2s) and rebuilding is correct and cheap.
const int _framePeriodMs = 20;

const String _waiver = 'ci:perf-ticker-setstate:';

Future<void> main() async {
  final failures = <String>[];
  final waivers = <String>[];
  var files = 0;

  final dartFiles = await Directory('lib')
      .list(recursive: true)
      .where((e) => e is File && e.path.endsWith('.dart'))
      .cast<File>()
      .toList();

  for (final file in dartFiles) {
    files++;
    final path = file.path.replaceAll('\\', '/');
    final src = await readTolerant(file);
    final lines = src.split('\n');
    final animVars = _animationIdentifiers(lines);

    for (var i = 0; i < lines.length; i++) {
      if (!lines[i].contains('setState')) continue;
      if (lines[i].contains(_waiver)) {
        waivers.add('$path:${i + 1}');
        continue;
      }
      final owner = _frameCallbackOwner(lines, i, animVars);
      if (owner == null) continue;
      failures.add(
        '$path:${i + 1}: setState inside $owner (per-frame rebuild). Drive the '
        'paint with a ValueNotifier + AnimatedBuilder / CustomPaint(repaint:), '
        'or if it genuinely cannot be, waive with `// $_waiver <reason>`.',
      );
    }
  }

  if (waivers.isNotEmpty) {
    stdout.writeln('[perf] ${waivers.length} waived:');
    for (final w in waivers) {
      stdout.writeln('  - $w');
    }
  }

  if (failures.isEmpty) {
    stdout.writeln(
      '[perf] OK: $files files, no setState driven by a frame-rate callback.',
    );
    return;
  }
  stderr.writeln('[perf] FAIL (${failures.length}):');
  for (final f in failures) {
    stderr.writeln('  - $f');
  }
  exit(1);
}

/// Identifiers assigned from `AnimationController(...)` or `Ticker(...)`, so a
/// later `<name>.addListener(` can be recognised as a frame-rate callback
/// rather than a text, focus or scroll listener.
Set<String> _animationIdentifiers(List<String> lines) {
  final names = <String>{};
  final pattern = RegExp(
    r'(\w+)\s*=\s*(?:AnimationController|Ticker)\s*\(',
  );
  for (final line in lines) {
    for (final m in pattern.allMatches(line)) {
      names.add(m.group(1)!);
    }
  }
  return names;
}

/// Describes the frame-rate callback enclosing [index], or null.
String? _frameCallbackOwner(
  List<String> lines,
  int index,
  Set<String> animVars,
) {
  // Bounded lookback: a `setState` far from its callback opener is far more
  // likely to be an event handler than a ticker body.
  for (var i = index; i >= 0 && index - i <= 14; i--) {
    final line = lines[i];

    // Timer.periodic is only a frame driver at a frame-rate period.
    if (line.contains('Timer.periodic(')) {
      if (_timerIsFrameRate(line, lines, i)) return 'Timer.periodic <= ${_framePeriodMs}ms';
      continue;
    }

    // The cascade form: AnimationController(vsync: ..)..addListener(
    if (line.contains('..addListener(')) return 'an AnimationController listener';

    // Ticker(onTick: ..). The lookbehind matters: without it a method named
    // _startClockTicker() reads as a Ticker construction.
    if (RegExp(r'(?<![A-Za-z0-9_])Ticker\(').hasMatch(line)) {
      return 'a Ticker callback';
    }

    // <name>.addListener( where <name> was assigned an AnimationController.
    for (final name in animVars) {
      if (line.contains('$name.addListener(')) {
        return 'the $name AnimationController listener';
      }
    }
  }
  return null;
}

/// True when the `Timer.periodic(` on [line] has a period <= [_framePeriodMs].
///
/// Reads the duration from the same statement or the next couple of lines, so
/// both `Timer.periodic(const Duration(milliseconds: 16), ..)` and a wrapped
/// multiline call are seen.
bool _timerIsFrameRate(String line, List<String> lines, int index) {
  final window = <String>[
    line,
    if (index + 1 < lines.length) lines[index + 1],
    if (index + 2 < lines.length) lines[index + 2],
  ].join(' ');
  final micros = RegExp(
    r'Duration\(\s*(micro|milli)?seconds:\s*(\d+)',
  ).firstMatch(window);
  if (micros == null) return false;
  final ms = switch (micros.group(1)) {
    // Duration(seconds: 1) has no prefix at all — an absent prefix is
    // SECONDS, not milliseconds. Reading it as millis turned every 1s clock
    // in the app into a phantom frame-rate violation.
    null => int.parse(micros.group(2)!) * 1000,
    'micro' => int.parse(micros.group(2)!) / 1000,
    _ => int.parse(micros.group(2)!),
  };
  return ms <= _framePeriodMs;
}