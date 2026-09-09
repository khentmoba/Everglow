// Asset-reference guard: every bundled path named in Dart must exist.
// Prevents the PR #66 class: milestone photos recompressed .png -> .jpg
// while stored code/docs still pointed at the deleted .png, rendering
// blank frames with no error fallback.
//
// Scans lib/**/*.dart for assets/... refs (png/jpg/jpeg/webp/json/ttf/
// mp3/glb/wasm) and resolves each against the repo tree. Directory
// entries from pubspec.yaml (trailing slash) resolve as prefixes.
//
// Intentional exception: lib/features/dashboard/domain/models/milestone.dart
// keeps a legacyAssetPathFixes map of stale .png KEYS that the read path
// rewrites on purpose. Those keys are skipped; every other ref must hit
// disk. If you rename or recompress an asset, update its refs (and add a
// read-path rewrite + migration like Milestone.repairLegacyImageUrl) or
// this check fails the PR.
//
// Usage: dart tool/ci/check_assets.dart
import 'dart:convert';
import 'dart:io';

// Lenient read: one non-UTF8 source file (extended-ASCII) must not break
// the scan; all markers we look for are ASCII.
Future<String> readTolerant(File f) =>
    f.readAsBytes().then((b) => utf8.decode(b, allowMalformed: true));

Future<void> main() async {
  final failures = <String>[];
  var checked = 0;

  final files = await Directory('lib')
      .list(recursive: true)
      .where((e) => e is File && e.path.endsWith('.dart'))
      .cast<File>()
      .toList();
  final assetPattern =
      RegExp(r'''assets/[A-Za-z0-9_./-]+\.(png|jpg|jpeg|webp|gif|svg|ico|json|ttf|otf|woff|woff2|mp3|glb|gltf|bin|data|wasm)''');

  for (final file in files) {
    final lines = (await readTolerant(file)).split('\n');
    final isLegacyMapHolder = file.path.endsWith(
      'lib/features/dashboard/domain/models/milestone.dart',
    );
    // Line range of the deliberate legacyAssetPathFixes rename map
    // (stale .png KEYS rewritten on read, not live loads). Skip refs
    // inside it by brace depth instead of a fixed window.
    var mapStart = -1, mapEnd = -1;
    if (isLegacyMapHolder) {
      for (var i = 0; i < lines.length; i++) {
        if (lines[i].contains('legacyAssetPathFixes')) mapStart = i;
        if (mapStart >= 0 && lines[i].contains('};')) {
          mapEnd = i;
          break;
        }
      }
    }
    for (var i = 0; i < lines.length; i++) {
      final inLegacyMap = mapStart >= 0 && i >= mapStart && i <= mapEnd;
      for (final m in assetPattern.allMatches(lines[i])) {
        var ref = m.group(0)!;
        // Inside the rename map only the stale .png KEYS are excused;
        // the .jpg targets are live assets and must still resolve.
        if (inLegacyMap && ref.endsWith('.png')) continue;
        // Raw web URLs (plain <img>/<model-viewer> src, JS GLB paths)
        // address the compiled bundle, where Flutter serves asset keys
        // under an extra `assets/` prefix: assets/assets/models/x.glb
        // on web == assets/models/x.glb in the repo. Normalize before
        // resolving (see cat_visuals_web.dart).
        if (ref.startsWith('assets/assets/')) {
          ref = ref.substring('assets/'.length);
        }
        checked++;
        if (!await File(ref).exists() && !await Directory(ref).exists()) {
          failures.add('${file.path}:${i + 1}: "$ref" not found on disk.');
        }
      }
    }
  }

  if (failures.isEmpty) {
    stdout.writeln('[assets] OK: $checked references resolve.');
    return;
  }
  stderr.writeln('[assets] FAIL (${failures.length}):');
  for (final f in failures) {
    stderr.writeln('  - $f');
  }
  stderr.writeln(
    '  If you renamed an asset, update its refs or add a read-path '
    'rewrite + stored-doc migration (see Milestone.repairLegacyImageUrl).',
  );
  exit(1);
}
