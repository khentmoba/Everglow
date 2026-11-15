import 'dart:io';

import '_io.dart';

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
    final isLegacyMapHolder = file.path.replaceAll('\\', '/').endsWith(
      'lib/features/dashboard/domain/models/milestone.dart',
    );
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
        if (inLegacyMap) continue;
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
