// ignore_for_file: subtype_of_sealed_class
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:everglow/features/gallery/data/services/gallery_service.dart';
import 'package:everglow/features/gallery/domain/models/memory_photo.dart';

class _Firestore implements FirebaseFirestore {
  _Firestore(this.events, {this.addError});

  final List<String> events;
  final Object? addError;

  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      _Collection(events, addError: addError);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Collection implements CollectionReference<Map<String, dynamic>> {
  _Collection(this.events, {this.addError});

  final List<String> events;
  final Object? addError;

  @override
  Future<DocumentReference<Map<String, dynamic>>> add(
    Map<String, dynamic> data,
  ) async {
    events.add('metadata-add');
    if (addError != null) throw addError!;
    return _Document('created', events);
  }

  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) =>
      _Document(path ?? 'new', events);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Document implements DocumentReference<Map<String, dynamic>> {
  _Document(this.id, this.events);

  @override
  final String id;
  final List<String> events;

  @override
  Future<void> delete() async => events.add('metadata-delete');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _fullUrl = 'https://storage.test/full.jpg';
const _thumbUrl = 'https://storage.test/thumb.jpg';

MemoryPhoto _photo({String? thumbUrl = _thumbUrl}) => MemoryPhoto(
  id: 'photo',
  imageUrl: _fullUrl,
  thumbUrl: thumbUrl,
  caption: 'A demo memory',
  uploadedBy: 'khentsgdz',
  uploadedAt: DateTime.utc(2026),
);

FirebaseException _storageError(String code) =>
    FirebaseException(plugin: 'firebase_storage', code: code);

Uint8List _testImage() =>
    Uint8List.fromList(img.encodeJpg(img.Image(width: 16, height: 12)));

void main() {
  test('deletes full and thumbnail before Firestore metadata', () async {
    final events = <String>[];
    final service = GalleryService(
      db: _Firestore(events),
      deleteStorageFile: (url) async => events.add('file:$url'),
    );

    await service.deletePhoto(_photo());

    expect(events, ['file:$_fullUrl', 'file:$_thumbUrl', 'metadata-delete']);
  });

  test('missing objects are success for direct and fallback deletes', () async {
    final events = <String>[];
    final service = GalleryService(
      db: _Firestore(events),
      deleteStorageFile: (url) async {
        events.add('file:$url');
        if (url == _fullUrl) throw _storageError('object-not-found');
        throw _storageError('permission-denied');
      },
      deleteStorageViaFunction: (url) async {
        events.add('fallback:$url');
        throw _storageError('object-not-found');
      },
    );

    await service.deletePhoto(_photo());

    expect(events, [
      'file:$_fullUrl',
      'file:$_thumbUrl',
      'fallback:$_thumbUrl',
      'metadata-delete',
    ]);
  });

  test(
    'fallback failure leaves metadata so UI can restore and retry',
    () async {
      final events = <String>[];
      final fallbackFailure = StateError('fallback unavailable');
      final service = GalleryService(
        db: _Firestore(events),
        deleteStorageFile: (_) async =>
            throw _storageError('permission-denied'),
        deleteStorageViaFunction: (_) async => throw fallbackFailure,
      );

      await expectLater(
        service.deletePhoto(_photo()),
        throwsA(same(fallbackFailure)),
      );
      expect(events, isEmpty);
    },
  );

  test(
    'uses fallback for partner files and only deletes metadata after success',
    () async {
      final events = <String>[];
      final service = GalleryService(
        db: _Firestore(events),
        deleteStorageFile: (url) async {
          events.add('direct:$url');
          throw _storageError('permission-denied');
        },
        deleteStorageViaFunction: (url) async => events.add('fallback:$url'),
      );

      await service.deletePhoto(_photo());

      expect(events, [
        'direct:$_fullUrl',
        'fallback:$_fullUrl',
        'direct:$_thumbUrl',
        'fallback:$_thumbUrl',
        'metadata-delete',
      ]);
    },
  );

  test(
    'metadata failure cleans both uploaded objects and preserves its error',
    () async {
      final events = <String>[];
      final addFailure = StateError('Firestore add failed');
      final service = GalleryService(
        db: _Firestore(events, addError: addFailure),
        uploadObject: (path, _) async {
          events.add('upload:$path');
          return 'https://storage.test/$path';
        },
        deleteStorageFile: (url) async {
          events.add('delete:$url');
          if (url.endsWith('_full.jpg')) {
            throw _storageError('permission-denied');
          }
        },
        deleteStorageViaFunction: (url) async {
          events.add('fallback:$url');
          throw StateError('cleanup failed');
        },
      );

      await expectLater(
        service.uploadPhoto(
          imageBytes: _testImage(),
          fileName: 'demo.jpg',
          caption: 'Demo',
          uploadedBy: 'khentsgdz',
          userId: 'demo-user',
        ),
        throwsA(same(addFailure)),
      );

      expect(events.length, 6);
      expect(events[0], startsWith('upload:gallery/demo-user/'));
      expect(events[0], endsWith('_full.jpg'));
      expect(events[1], startsWith('upload:gallery/demo-user/'));
      expect(events[1], endsWith('_thumb.jpg'));
      expect(events[2], 'metadata-add');
      expect(events[3], startsWith('delete:https://storage.test/gallery/'));
      expect(events[3], endsWith('_full.jpg'));
      expect(events[4], startsWith('fallback:https://storage.test/gallery/'));
      expect(events[4], endsWith('_full.jpg'));
      expect(events[5], startsWith('delete:https://storage.test/gallery/'));
      expect(events[5], endsWith('_thumb.jpg'));
    },
  );

  test('does not clean uploaded objects after metadata is saved', () async {
    final events = <String>[];
    final service = GalleryService(
      db: _Firestore(events),
      uploadObject: (path, _) async {
        events.add('upload:$path');
        return 'https://storage.test/$path';
      },
      deleteStorageFile: (url) async => events.add('delete:$url'),
    );

    final photo = await service.uploadPhoto(
      imageBytes: _testImage(),
      fileName: 'demo.jpg',
      caption: 'Demo',
      uploadedBy: 'khentsgdz',
      userId: 'demo-user',
    );

    expect(photo.id, 'created');
    expect(events.last, 'metadata-add');
    expect(events.where((event) => event.startsWith('delete:')), isEmpty);
  });
}
