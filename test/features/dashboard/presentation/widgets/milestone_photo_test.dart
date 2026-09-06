import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:everglow/features/dashboard/presentation/widgets/timeline_view.dart';

void main() {
  group('MilestonePhoto', () {
    testWidgets('shows a visible fallback instead of a blank frame when '
        'a bundled photo is missing', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              height: 300,
              child: MilestonePhoto(
                path: 'assets/images/milestones/does_not_exist.jpg',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.broken_image_rounded), findsOneWidget);
    });
  });
}
