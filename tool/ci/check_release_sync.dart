// Release-sync guard: the shipped version must match its paperwork.
//
// Khent decided releases are manual and curated, never automatic
// (auto-releases once cluttered the page with date tags; see 4b451a2).
// So CI must not publish releases — but every PR must keep these four
// in agreement, or the README badge, changelog, and releases page drift:
//
// 1. pubspec.yaml `version: X.Y.Z+N` (source of truth)
// 2. lib/core/system/app_version.dart `current` (runtime mirror)
// 3. CHANGELOG.md `## [X.Y.Z]` entry (release notes live here)
// 4. README.md `Latest Release` + `Release History` (what GitHub shows)
//
// When cutting a release, bump all four in one PR (see "Releases" in
// AGENTS.md). Feature PRs change none of them.
//
// Usage: dart tool/ci/check_release_sync.dart
import 'dart:io';

Future<void> main() async {
  final failures = <String>[];

  final pubspec = await _read('pubspec.yaml', failures);
  final appVersion =
      await _read('lib/core/system/app_version.dart', failures);
  final changelog = await _read('CHANGELOG.md', failures);
  final readme = await _read('README.md', failures);
  if (failures.isNotEmpty) {
    _fail(failures);
  }

  final pubMatch =
      RegExp(r'^version:\s*(\S+)', multiLine: true).firstMatch(pubspec!);
  if (pubMatch == null) {
    _fail(['pubspec.yaml has no `version:` line.']);
  }
  final full = pubMatch.group(1)!;
  final semver = full.split('+').first;
  if (!RegExp(r'^\d+\.\d+\.\d+$').hasMatch(semver)) {
    _fail(['pubspec version "$full" is not X.Y.Z(+N).']);
  }

  final appMatch =
      RegExp(r"current\s*=\s*'([^']+)'").firstMatch(appVersion!);
  if (appMatch == null || appMatch.group(1) != full) {
    failures.add(
      'AppVersion.current is "${appMatch?.group(1)}", expected "$full". '
      'Bump lib/core/system/app_version.dart with pubspec.yaml.',
    );
  }

  if (!RegExp('^## \\[${RegExp.escape(semver)}\\]',
          multiLine: true)
      .hasMatch(changelog!)) {
    failures.add(
      'CHANGELOG.md has no `## [$semver]` entry. '
      'Add release notes on top for every version bump.',
    );
  }

  final latest = _section(readme!, '## Latest Release');
  if (latest == null || !latest.contains('v$semver')) {
    failures.add(
      'README.md `Latest Release` does not mention v$semver. '
      'Mirror the CHANGELOG entry there on every release.',
    );
  }
  final history = _section(readme, '## Release History');
  if (history == null ||
      !history.contains('v$semver') ||
      !history.contains('releases/tag/v$semver')) {
    failures.add(
      'README.md `Release History` does not list v$semver with a '
      'releases/tag/v$semver link. Add one line per release.',
    );
  }

  if (failures.isEmpty) {
    stdout.writeln('[release] OK: v$semver in sync '
        '(pubspec, AppVersion, CHANGELOG, README).');
    return;
  }
  _fail(failures);
}

/// Returns the markdown section starting at [heading], up to (but not
/// including) the next `## ` heading, or null when missing.
String? _section(String text, String heading) {
  final start = text.indexOf(heading);
  if (start < 0) return null;
  final rest = text.substring(start + heading.length);
  final end = rest.indexOf('\n## ');
  return end < 0 ? rest : rest.substring(0, end);
}

Future<String?> _read(String path, List<String> failures) async {
  final file = File(path);
  if (!await file.exists()) {
    failures.add('$path not found; run from repo root.');
    return null;
  }
  return file.readAsString();
}

Never _fail(List<String> failures) {
  stderr.writeln('[release] FAIL (${failures.length}):');
  for (final f in failures) {
    stderr.writeln('  - $f');
  }
  exit(1);
}
