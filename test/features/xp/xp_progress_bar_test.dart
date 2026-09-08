import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:everglow/features/xp/domain/models/user_progress.dart';
import 'package:everglow/features/xp/presentation/widgets/xp_progress_bar.dart';

void main() {
  testWidgets('XPProgressBar renders without throwing on zero or narrow constraints', (tester) async {
    final progress = UserProgress(
      uid: 'user1',
      xpTotal: 50,
      level: 1,
      streak: 1,
      lastActivity: DateTime(2026, 9, 8),
    );

    // Box with zero width constraints — previously threw "Invalid argument: 0"
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 0,
            child: XPProgressBar(progress: progress),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);

    // Box with very narrow constraints (< 14px)
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 5,
            child: XPProgressBar(progress: progress),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
