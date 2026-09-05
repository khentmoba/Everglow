import 'package:flutter_test/flutter_test.dart';

import 'package:everglow/features/vault/data/models/vault_entry.dart';

VaultEntry _entry() => VaultEntry(
      id: 'v1',
      fileName: 'tickets.pdf',
      fileUrl: 'http://files/tickets.pdf',
      fileSize: 2048,
      mimeType: 'application/pdf',
      uploadedBy: 'khent',
      uploadedAt: DateTime.utc(2026, 9, 1),
      tags: const ['trip'],
      folder: 'documents',
    );

void main() {
  group('VaultEntry', () {
    test('sizeLabel formats bytes, KB and MB', () {
      VaultEntry sized(int bytes) => VaultEntry(
            id: 'v',
            fileName: 'f',
            fileUrl: 'u',
            fileSize: bytes,
            mimeType: 'text/plain',
            uploadedBy: 'clair',
            uploadedAt: DateTime.utc(2026, 9, 1),
          );

      expect(sized(512).sizeLabel, '512 B');
      expect(sized(2048).sizeLabel, '2.0 KB');
      expect(sized(5 * 1024 * 1024).sizeLabel, '5.0 MB');
    });

    test('type flags spot images and PDFs', () {
      expect(_entry().isPdf, isTrue);
      expect(_entry().isImage, isFalse);
      final photo = VaultEntry(
        id: 'v2',
        fileName: 'sunset.jpg',
        fileUrl: 'u',
        fileSize: 100,
        mimeType: 'image/jpeg',
        uploadedBy: 'clair',
        uploadedAt: DateTime.utc(2026, 9, 1),
      );
      expect(photo.isImage, isTrue);
      expect(photo.isPdf, isFalse);
    });

    test('toFirestore keeps every field', () {
      final map = _entry().toFirestore();

      expect(map['fileName'], 'tickets.pdf');
      expect(map['fileSize'], 2048);
      expect(map['mimeType'], 'application/pdf');
      expect(map['folder'], 'documents');
      expect(map['tags'], ['trip']);
    });
  });
}
