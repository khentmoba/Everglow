// A genuine case can be waived with `// ci:perf-ticker-setstate: <reason>`,
import 'dart:io';

import '_io.dart';

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

String? _frameCallbackOwner(
  List<String> lines,
  int index,
  Set<String> animVars,
) {
  for (var i = index; i >= 0 && index - i <= 14; i--) {
    final line = lines[i];

    if (line.contains('Timer.periodic(')) {
      if (_timerIsFrameRate(line, lines, i)) return 'Timer.periodic <= ${_framePeriodMs}ms';
      continue;
    }

    if (line.contains('..addListener(')) return 'an AnimationController listener';

    if (RegExp(r'(?<![A-Za-z0-9_])Ticker\(').hasMatch(line)) {
      return 'a Ticker callback';
    }

    for (final name in animVars) {
      if (line.contains('$name.addListener(')) {
        return 'the $name AnimationController listener';
      }
    }
  }
  return null;
}

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
    null => int.parse(micros.group(2)!) * 1000,
    'micro' => int.parse(micros.group(2)!) / 1000,
    _ => int.parse(micros.group(2)!),
  };
  return ms <= _framePeriodMs;
}