import 'package:cloud_firestore/cloud_firestore.dart';

class VaultEntry {
  final String id;
  final String fileName;
  final String fileUrl;
  final int fileSize;
  final String mimeType;
  final String uploadedBy;
  final DateTime uploadedAt;
  final List<String> tags;
  final String folder; // e.g., "photos", "documents", "tickets"

  const VaultEntry({
    required this.id,
    required this.fileName,
    required this.fileUrl,
    required this.fileSize,
    required this.mimeType,
    required this.uploadedBy,
    required this.uploadedAt,
    this.tags = const [],
    this.folder = 'general',
  });

  factory VaultEntry.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return VaultEntry(
      id: doc.id,
      fileName: data['fileName'] ?? '',
      fileUrl: data['fileUrl'] ?? '',
      fileSize: (data['fileSize'] ?? 0) is int ? data['fileSize'] : int.tryParse(data['fileSize'].toString()) ?? 0,
      mimeType: data['mimeType'] ?? 'application/octet-stream',
      uploadedBy: data['uploadedBy'] ?? '',
      uploadedAt: (data['uploadedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      tags: (data['tags'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
      folder: data['folder'] ?? 'general',
    );
  }

  Map<String, dynamic> toFirestore() => {
        'fileName': fileName,
        'fileUrl': fileUrl,
        'fileSize': fileSize,
        'mimeType': mimeType,
        'uploadedBy': uploadedBy,
        'uploadedAt': Timestamp.fromDate(uploadedAt),
        'tags': tags,
        'folder': folder,
      };

  String get sizeLabel {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  bool get isImage => mimeType.startsWith('image/');
  bool get isPdf => mimeType == 'application/pdf';
}
