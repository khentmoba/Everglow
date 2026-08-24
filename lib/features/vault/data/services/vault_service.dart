import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../../../core/utils/firestore_stream_utils.dart';
import '../../../../core/utils/logger.dart';
import '../models/vault_entry.dart';

class VaultService {
  static final VaultService _instance = VaultService._internal();
  factory VaultService() => _instance;
  VaultService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final String _collection = 'vault_entries';

  Stream<List<VaultEntry>> watchAll() => withFirestoreTimeout(
    _db
        .collection(_collection)
        .orderBy('uploadedAt', descending: true)
        .limit(100)
        .snapshots()
        .map((s) => s.docs.map((d) => VaultEntry.fromFirestore(d)).toList()),
    label: 'vault-all',
  );

  Stream<List<VaultEntry>> watchByFolder(String folder) => withFirestoreTimeout(
    _db
        .collection(_collection)
        .orderBy('uploadedAt', descending: true)
        .limit(100)
        .snapshots()
        .map(
          (s) => s.docs
              .map((d) => VaultEntry.fromFirestore(d))
              .where((e) => e.folder == folder)
              .toList(),
        ),
    label: 'vault-folder-$folder',
  );

  Future<VaultEntry?> uploadFile({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
    required String uploadedBy,
    required String userId,
    String folder = 'general',
    List<String> tags = const [],
  }) async {
    try {
      final path =
          'vault/$userId/${DateTime.now().millisecondsSinceEpoch}_$fileName';
      final ref = _storage.ref().child(path);
      final task = await ref.putData(
        bytes,
        SettableMetadata(
          contentType: mimeType,
          cacheControl: 'public, max-age=604800',
        ),
      );
      final url = await task.ref.getDownloadURL();
      final entry = VaultEntry(
        id: '',
        fileName: fileName,
        fileUrl: url,
        fileSize: bytes.length,
        mimeType: mimeType,
        uploadedBy: uploadedBy,
        uploadedAt: DateTime.now(),
        tags: tags,
        folder: folder,
      );
      final doc = await _db.collection(_collection).add(entry.toFirestore());
      Logger.i('Vault uploaded: $fileName → $url');
      return VaultEntry(
        id: doc.id,
        fileName: fileName,
        fileUrl: url,
        fileSize: bytes.length,
        mimeType: mimeType,
        uploadedBy: uploadedBy,
        uploadedAt: DateTime.now(),
        tags: tags,
        folder: folder,
      );
    } catch (e) {
      Logger.e('Vault upload failed', error: e);
      return null;
    }
  }

  Future<void> deleteEntry(VaultEntry entry) async {
    try {
      await _db.collection(_collection).doc(entry.id).delete();
      try {
        final ref = _storage.refFromURL(entry.fileUrl);
        await ref.delete();
      } catch (_) {}
      Logger.i('Vault deleted: ${entry.id}');
    } catch (e) {
      Logger.e('Vault delete failed', error: e);
    }
  }

  Future<Map<String, int>> getStorageStats() async {
    final snap = await _db.collection(_collection).limit(200).get();
    final entries = snap.docs.map((d) => VaultEntry.fromFirestore(d)).toList();
    final total = entries.length;
    final bytes = entries.fold<int>(0, (acc, e) => acc + e.fileSize);
    return {'count': total, 'bytes': bytes};
  }
}
