// One-off repair: legacy gallery photos were uploaded before the
// resize+thumbnail feature existed. They store full original resolution
// with no thumbUrl, so the grid downloads multi-MB images and photos
// larger than ~16MP fail to decode on iOS Safari / GPU-limited devices.
//
// For each gallery doc without a thumbUrl:
//   1. Download the current full image.
//   2. Re-encode a 1600px full (matches upload path) + a 400px thumb.
//   3. Upload both to Storage, update the Firestore doc.
//   4. Delete the old oversized full object.
//
// Auth: reuses the firebase-tools OAuth access token from configstore.
// Run:  dart run bin/backfill.dart

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

const projectId = 'everglow-1c6db';
const bucket = '$projectId.firebasestorage.app';
const functionsHost = 'https://us-central1-$projectId.cloudfunctions.net';

String _token() {
  final home = Platform.environment['HOME']!;
  final conf = File(
    '$home/.config/configstore/firebase-tools.json',
  ).readAsStringSync();
  final tokens = jsonDecode(conf)['tokens'];
  return tokens['access_token'] as String;
}

Future<Uint8List?> _fetchViaProxy(String url) async {
  final proxied =
      '$functionsHost/proxyGalleryImage?url=${Uri.encodeComponent(url)}';
  final resp = await http.get(Uri.parse(proxied));
  if (resp.statusCode != 200) {
    stderr.writeln('  proxy fetch failed ${resp.statusCode}');
    return null;
  }
  return resp.bodyBytes;
}

Uint8List? _resizedJpeg(Uint8List bytes, int maxSize) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;
  final longest = decoded.width > decoded.height
      ? decoded.width
      : decoded.height;
  final resized = longest <= maxSize
      ? decoded
      : img.copyResize(
          decoded,
          width: decoded.width >= decoded.height ? maxSize : null,
          height: decoded.height > decoded.width ? maxSize : null,
        );
  return Uint8List.fromList(img.encodeJpg(resized, quality: 85));
}

/// Uploads bytes to Storage, returns a download URL with a fresh token.
Future<String?> _upload(String storagePath, Uint8List bytes) async {
  final uri = Uri.parse(
    'https://firebasestorage.googleapis.com/v0/b/$bucket/o'
    '?uploadType=media&name=${Uri.encodeComponent(storagePath)}',
  );
  final resp = await http.post(
    uri,
    headers: {
      'Authorization': 'Bearer ${_token()}',
      'Content-Type': 'image/jpeg',
    },
    body: bytes,
  );
  if (resp.statusCode != 200) {
    stderr.writeln('  upload failed ${resp.statusCode}: ${resp.body}');
    return null;
  }
  final meta = jsonDecode(resp.body);
  final token = meta['downloadTokens'];
  if (token == null || (token as String).isEmpty) {
    stderr.writeln('  no downloadTokens in response: ${resp.body}');
    return null;
  }
  return 'https://firebasestorage.googleapis.com/v0/b/$bucket/o/'
      '${Uri.encodeComponent(storagePath)}?alt=media&token=$token';
}

Future<bool> _deleteObject(String fullUrl) async {
  // https://.../o/<encoded path>?alt=media&token=...
  final uri = Uri.parse(fullUrl);
  final path = uri.pathSegments.last;
  final delUri = Uri.parse(
    'https://firebasestorage.googleapis.com/v0/b/$bucket/o/$path',
  );
  final resp = await http.delete(
    delUri,
    headers: {'Authorization': 'Bearer ${_token()}'},
  );
  return resp.statusCode == 200 || resp.statusCode == 204;
}

Future<bool> _updateDoc(String docId, String imageUrl, String thumbUrl) async {
  final uri = Uri.parse(
    'https://firestore.googleapis.com/v1/projects/$projectId/'
    'databases/(default)/documents/gallery/$docId'
    '?updateMask.fieldPaths=imageUrl&updateMask.fieldPaths=thumbUrl',
  );
  final body = jsonEncode({
    'fields': {
      'imageUrl': {'stringValue': imageUrl},
      'thumbUrl': {'stringValue': thumbUrl},
    },
  });
  final resp = await http.patch(
    uri,
    headers: {
      'Authorization': 'Bearer ${_token()}',
      'Content-Type': 'application/json',
    },
    body: body,
  );
  if (resp.statusCode != 200) {
    stderr.writeln('  firestore update ${resp.statusCode}: ${resp.body}');
  }
  return resp.statusCode == 200;
}

Future<void> main() async {
  // 1. List all gallery docs via Firestore REST.
  final qUri = Uri.parse(
    'https://firestore.googleapis.com/v1/projects/$projectId/'
    'databases/(default)/documents:runQuery',
  );
  final qResp = await http.post(
    qUri,
    headers: {
      'Authorization': 'Bearer ${_token()}',
      'Content-Type': 'application/json',
    },
    body: jsonEncode({
      'structuredQuery': {
        'from': [
          {'collectionId': 'gallery'},
        ],
        'orderBy': {
          'field': {'fieldPath': 'uploadedAt'},
          'direction': 'DESCENDING',
        },
      },
    }),
  );
  if (qResp.statusCode != 200) {
    stderr.writeln('query failed ${qResp.statusCode}: ${qResp.body}');
    exitCode = 1;
    return;
  }

  final docs = <Map<String, dynamic>>[];
  // Firestore REST returns a single pretty-printed JSON array of
  // per-document result objects; split top-level {..} blocks.
  final joined = qResp.body.trim();
  final blocks = <String>[];
  var depth = 0;
  var start = -1;
  for (var i = 0; i < joined.length; i++) {
    final c = joined[i];
    if (c == '{') {
      if (depth == 0) start = i;
      depth++;
    } else if (c == '}') {
      depth--;
      if (depth == 0 && start >= 0) {
        blocks.add(joined.substring(start, i + 1));
        start = -1;
      }
    }
  }
  for (final block in blocks) {
    final obj = jsonDecode(block);
    final doc = obj['document'];
    if (doc == null) continue;
    final f = (doc['fields'] ?? {}) as Map<String, dynamic>;
    final imageUrl = f['imageUrl']?['stringValue'] as String? ?? '';
    final thumbUrl = f['thumbUrl']?['stringValue'] as String?;
    final caption = f['caption']?['stringValue'] as String? ?? '';
    docs.add({
      'id': (doc['name'] as String).split('/').last,
      'imageUrl': imageUrl,
      'thumbUrl': thumbUrl,
      'caption': caption,
    });
  }

  final needsFix = docs
      .where((d) => (d['thumbUrl'] as String?)?.isEmpty != false)
      .toList();
  stdout.writeln(
    'gallery docs: ${docs.length}, missing thumb: ${needsFix.length}',
  );

  for (final doc in needsFix) {
    final id = doc['id'] as String;
    final oldUrl = doc['imageUrl'] as String;
    final caption = doc['caption'] as String;
    stdout.writeln('\n=== $id "$caption"');
    stdout.writeln('  downloading full via proxy...');
    final bytes = await _fetchViaProxy(oldUrl);
    if (bytes == null) {
      stderr.writeln('  SKIP: could not fetch');
      continue;
    }
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      stderr.writeln('  SKIP: not a decodable image');
      continue;
    }
    stdout.writeln(
      '  original: ${decoded.width}x${decoded.height}, ${bytes.length} bytes',
    );

    final fullBytes = _resizedJpeg(bytes, 1600) ?? bytes;
    final thumbBytes = _resizedJpeg(bytes, 400);
    stdout.writeln(
      '  full: ${fullBytes.length} bytes, thumb: ${thumbBytes?.length ?? 0} bytes',
    );

    final stamp = DateTime.now().millisecondsSinceEpoch;
    final newFull = await _upload(
      'gallery/migrated/${stamp}_$id\_full.jpg',
      fullBytes,
    );
    if (newFull == null) {
      stderr.writeln('  SKIP: full upload failed');
      continue;
    }
    String? newThumb;
    if (thumbBytes != null) {
      newThumb = await _upload(
        'gallery/migrated/${stamp}_$id\_thumb.jpg',
        thumbBytes,
      );
    }
    if (newThumb == null) {
      stderr.writeln('  SKIP: thumb upload failed (full already uploaded)');
      continue;
    }

    final ok = await _updateDoc(id, newFull, newThumb);
    if (!ok) {
      stderr.writeln(
        '  FAIL: firestore update failed; new URLs NOT wired. full=$newFull',
      );
      continue;
    }
    stdout.writeln('  firestore updated');

    // Only delete the old object after the doc points at the new ones.
    final deleted = await _deleteObject(oldUrl);
    stdout.writeln('  old object deleted: $deleted');
    stdout.writeln('  DONE: $id');
  }

  stdout.writeln('\nall done');
}
