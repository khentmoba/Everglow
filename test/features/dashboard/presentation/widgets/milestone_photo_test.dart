import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:everglow/features/dashboard/presentation/widgets/milestone_photo.dart';

void main() {
  group('MilestonePhoto', () {
    testWidgets('shows fallback when private storage denies access', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              height: 300,
              child: MilestonePhoto(
                path: 'milestones/legacy/private.jpg',
                privatePhotoLoader: (_) => Future.error(StateError('denied')),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.broken_image_rounded), findsOneWidget);
    });

    testWidgets('shows fallback when private storage returns no bytes', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              height: 300,
              child: MilestonePhoto(
                path: 'milestones/legacy/missing.jpg',
                privatePhotoLoader: (_) async => null,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.broken_image_rounded), findsOneWidget);
    });

    testWidgets('continues to load safe demo artwork as a bundled asset', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              height: 300,
              child: MilestonePhoto(path: 'assets/images/demo/poster-1.jpg'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsOneWidget);
      expect(tester.widget<Image>(find.byType(Image)).image, isA<AssetImage>());
    });
  });
}
