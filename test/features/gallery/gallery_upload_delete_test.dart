import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:provider/provider.dart';

import 'package:everglow/core/services/auth_service.dart';
import 'package:everglow/features/gallery/data/services/gallery_service.dart';
import 'package:everglow/features/gallery/domain/models/memory_photo.dart';
import 'package:everglow/features/gallery/presentation/screens/photo_viewer_screen.dart';

class _TestHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return _FakeHttpClient();
  }
}

class _FakeHttpClient implements HttpClient {
  @override
  bool autoUncompress = true;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _FakeHttpClientRequest();

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeHttpClientRequest implements HttpClientRequest {
  @override
  final HttpHeaders headers = _FakeHttpHeaders();

  @override
  Future<HttpClientResponse> close() async => _FakeHttpClientResponse();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpHeaders implements HttpHeaders {
  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpClientResponse extends Stream<List<int>>
    implements HttpClientResponse {
  static final _kTransparentPng = Uint8List.fromList([
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
    0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
    0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
    0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
    0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
    0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
  ]);

  @override
  int get statusCode => 200;

  @override
  int get contentLength => _kTransparentPng.length;

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.value(_kTransparentPng).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAuthService extends ChangeNotifier implements AuthService {
  _FakeAuthService({this.testUid = 'khent-uid', this.testUser = 'khentsgdz'});

  final String testUid;
  final String testUser;

  @override
  String? get uid => testUid;

  @override
  String? get currentUser => testUser;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Uint8List _createTestImageBytes(int width, int height) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(200, 100, 50));
  return Uint8List.fromList(img.encodeJpg(image));
}

MemoryPhoto _photo({
  required String id,
  required String uploader,
  String? thumbUrl,
}) =>
    MemoryPhoto(
      id: id,
      imageUrl: 'https://firebasestorage.googleapis.com/v0/b/app/o/$id.jpg',
      thumbUrl: thumbUrl,
      caption: 'Photo $id',
      uploadedBy: uploader,
      uploadedAt: DateTime.utc(2026, 9, 1, 12),
    );

void main() {
  setUpAll(() {
    HttpOverrides.global = _TestHttpOverrides();
  });
  group('Gallery Image Resizing & Encoding (Upload Safety)', () {
    test('downscales large landscape image to max 1600 edge', () {
      final inputBytes = _createTestImageBytes(2400, 1200);
      final resizedBytes = GalleryService.resizedJpeg(inputBytes, 1600);

      expect(resizedBytes, isNotNull);
      final decoded = img.decodeImage(resizedBytes!);
      expect(decoded, isNotNull);
      expect(decoded!.width, 1600);
      expect(decoded.height, 800);
      // Valid JPEG header
      expect(resizedBytes[0], 0xFF);
      expect(resizedBytes[1], 0xD8);
    });

    test('downscales large portrait image to max 1600 edge', () {
      final inputBytes = _createTestImageBytes(1200, 2400);
      final resizedBytes = GalleryService.resizedJpeg(inputBytes, 1600);

      expect(resizedBytes, isNotNull);
      final decoded = img.decodeImage(resizedBytes!);
      expect(decoded, isNotNull);
      expect(decoded!.width, 800);
      expect(decoded.height, 1600);
    });

    test('downscales thumbnail to max 400 edge', () {
      final inputBytes = _createTestImageBytes(1000, 800);
      final thumbBytes = GalleryService.resizedJpeg(inputBytes, 400);

      expect(thumbBytes, isNotNull);
      final decoded = img.decodeImage(thumbBytes!);
      expect(decoded, isNotNull);
      expect(decoded!.width, 400);
      expect(decoded.height, 320);
    });

    test('does not upscale smaller image', () {
      final inputBytes = _createTestImageBytes(300, 200);
      final outputBytes = GalleryService.resizedJpeg(inputBytes, 1600);

      expect(outputBytes, isNotNull);
      final decoded = img.decodeImage(outputBytes!);
      expect(decoded, isNotNull);
      expect(decoded!.width, 300);
      expect(decoded.height, 200);
    });

    test('returns null for corrupt or non-image bytes (graceful fallback)', () {
      final corruptBytes = Uint8List.fromList([0, 1, 2, 3, 4, 5]);
      final output = GalleryService.resizedJpeg(corruptBytes, 1600);
      expect(output, isNull);
    });
  });

  group('Gallery Storage Paths & File Sanitization', () {
    test('sanitizes unsafe characters, paths and spaces in file names', () {
      expect(
        GalleryService.sanitizeFileName('photo 1.jpg'),
        'photo_1.jpg',
      );
      expect(
        GalleryService.sanitizeFileName('../../secret/pic.png'),
        '.._.._secret_pic.png',
      );
      expect(
        GalleryService.sanitizeFileName('sunset:batangas?clair!.jpg'),
        'sunset_batangas_clair_.jpg',
      );
    });

    test('builds predictable storage base path with user isolation', () {
      final path = GalleryService.storageBasePath(
        userId: 'uid_khent',
        fileName: 'trip photo.jpg',
        timestamp: 1726000000000,
      );
      expect(path, 'gallery/uid_khent/1726000000000_trip_photo.jpg');
    });
  });

  group('Gallery Display URL & Web Proxying', () {
    const storageUrl =
        'https://firebasestorage.googleapis.com/v0/b/app/o/photos%2Fp1.jpg?alt=media';
    const nonStorageUrl = 'https://images.example.com/pic.jpg';

    test('proxies Firebase Storage URLs on web to bypass CORS', () {
      final proxied = GalleryService.displayUrl(storageUrl, isWeb: true);
      expect(
        proxied,
        startsWith(
          'https://us-central1-everglow-1c6db.cloudfunctions.net/proxyGalleryImage?url=',
        ),
      );
      expect(proxied, contains(Uri.encodeComponent(storageUrl)));
      expect(proxied, isNot(contains('&w=440')));
    });

    test('appends w=440 thumbnail cache hint on web', () {
      final thumbProxied = GalleryService.displayUrl(
        storageUrl,
        thumb: true,
        isWeb: true,
      );
      expect(thumbProxied, endsWith('&w=440'));
    });

    test('never proxies non-FirebaseStorage URLs on web', () {
      expect(
        GalleryService.displayUrl(nonStorageUrl, isWeb: true),
        nonStorageUrl,
      );
    });

    test('never proxies on mobile / non-web platforms', () {
      expect(
        GalleryService.displayUrl(storageUrl, thumb: true, isWeb: false),
        storageUrl,
      );
    });
  });

  group('Gallery Metadata Payload for Firestore', () {
    test('builds full metadata payload including geo and tags', () {
      final taken = DateTime.utc(2026, 9, 21, 10, 30);
      final map = GalleryService.buildMetadataPayload(
        imageUrl: 'http://img/full.jpg',
        thumbUrl: 'http://img/thumb.jpg',
        caption: 'Our anniversary dinner',
        uploadedBy: 'khentsgdz',
        tags: ['dinner', 'anniversary'],
        now: DateTime.utc(2026, 9, 21),
        latitude: 14.5995,
        longitude: 120.9842,
        locationName: 'Manila Bay',
        takenAt: taken,
        uploadedAtFieldValue: 'SERVER_TIMESTAMP',
      );

      expect(map['imageUrl'], 'http://img/full.jpg');
      expect(map['thumbUrl'], 'http://img/thumb.jpg');
      expect(map['caption'], 'Our anniversary dinner');
      expect(map['uploadedBy'], 'khentsgdz');
      expect(map['tags'], ['dinner', 'anniversary']);
      expect(map['monthDay'], '09-21');
      expect(map['latitude'], 14.5995);
      expect(map['longitude'], 120.9842);
      expect(map['locationName'], 'Manila Bay');
      expect(map['takenAt'], isA<Timestamp>());
      expect(map['uploadedAt'], 'SERVER_TIMESTAMP');
    });

    test('omits optional null or empty fields from metadata map', () {
      final map = GalleryService.buildMetadataPayload(
        imageUrl: 'http://img/full.jpg',
        caption: 'Solo memory',
        uploadedBy: 'clairjassen',
        now: DateTime.utc(2026, 2, 14),
        locationName: '',
      );

      expect(map.containsKey('thumbUrl'), isFalse);
      expect(map.containsKey('latitude'), isFalse);
      expect(map.containsKey('longitude'), isFalse);
      expect(map.containsKey('locationName'), isFalse);
      expect(map.containsKey('takenAt'), isFalse);
      expect(map['monthDay'], '02-14');
    });
  });

  group('PhotoViewerScreen Delete Flow & Optimistic Rollback', () {
    Widget createViewerApp({
      required List<MemoryPhoto> photos,
      required AuthService authService,
      Future<void> Function(MemoryPhoto)? onDelete,
    }) {
      return ChangeNotifierProvider<AuthService>.value(
        value: authService,
        child: MaterialApp(
          home: PhotoViewerScreen(
            photos: photos,
            onDelete: onDelete,
          ),
        ),
      );
    }

    testWidgets('shows delete icon for owner and allows canceling deletion', (
      tester,
    ) async {
      final auth = _FakeAuthService(testUid: 'u1', testUser: 'khentsgdz');
      final photos = [
        _photo(id: 'p1', uploader: 'khentsgdz'),
      ];

      await tester.pumpWidget(
        createViewerApp(photos: photos, authService: auth),
      );
      await tester.pumpAndSettle();

      final deleteButton = find.byIcon(Icons.delete_outline_rounded);
      expect(deleteButton, findsOneWidget);

      await tester.tap(deleteButton);
      await tester.pumpAndSettle();

      expect(find.text('Delete Photo?'), findsOneWidget);
      expect(find.text('This action cannot be undone.'), findsOneWidget);

      // Tap Cancel
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Delete Photo?'), findsNothing);
      expect(find.text('1 / 1'), findsOneWidget);
    });

    testWidgets('hides delete icon when viewing partner photo', (
      tester,
    ) async {
      final auth = _FakeAuthService(testUid: 'u1', testUser: 'khentsgdz');
      final photos = [
        _photo(id: 'p_partner', uploader: 'clairjassen'),
      ];

      await tester.pumpWidget(
        createViewerApp(photos: photos, authService: auth),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.delete_outline_rounded), findsNothing);
    });

    testWidgets('optimistically deletes photo from viewer list', (
      tester,
    ) async {
      final auth = _FakeAuthService(testUid: 'u1', testUser: 'khentsgdz');
      final photos = [
        _photo(id: 'p1', uploader: 'khentsgdz'),
        _photo(id: 'p2', uploader: 'khentsgdz'),
      ];

      MemoryPhoto? deletedPhoto;
      await tester.pumpWidget(
        createViewerApp(
          photos: photos,
          authService: auth,
          onDelete: (photo) async {
            deletedPhoto = photo;
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('1 / 2'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.delete_outline_rounded));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(deletedPhoto?.id, 'p1');
      expect(find.text('1 / 1'), findsOneWidget);
    });

    testWidgets('rolls back photo when delete action throws an error', (
      tester,
    ) async {
      final auth = _FakeAuthService(testUid: 'u1', testUser: 'khentsgdz');
      final photos = [
        _photo(id: 'p1', uploader: 'khentsgdz'),
        _photo(id: 'p2', uploader: 'khentsgdz'),
      ];

      await tester.pumpWidget(
        createViewerApp(
          photos: photos,
          authService: auth,
          onDelete: (photo) async {
            throw Exception('Network failed');
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('1 / 2'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.delete_outline_rounded));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      // Should show rollback SnackBar
      expect(find.text('Failed to delete photo. Restored.'), findsOneWidget);
      // Photo count is restored back to 2
      expect(find.text('1 / 2'), findsOneWidget);
    });

    testWidgets('pops screen immediately when deleting the last photo', (
      tester,
    ) async {
      final auth = _FakeAuthService(testUid: 'u1', testUser: 'khentsgdz');
      final photos = [
        _photo(id: 'only_photo', uploader: 'khentsgdz'),
      ];

      var deleted = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => ChangeNotifierProvider<AuthService>.value(
                        value: auth,
                        child: PhotoViewerScreen(
                          photos: photos,
                          onDelete: (photo) async {
                            deleted = true;
                          },
                        ),
                      ),
                    ),
                  );
                },
                child: const Text('Open Viewer'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Viewer'));
      await tester.pumpAndSettle();

      expect(find.text('1 / 1'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.delete_outline_rounded));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      // Screen is popped back to root
      expect(deleted, isTrue);
      expect(find.text('Open Viewer'), findsOneWidget);
      expect(find.text('1 / 1'), findsNothing);
    });
  });
}
