import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:everglow/core/theme/app_colors.dart';
import 'package:everglow/features/dashboard/presentation/widgets/feature_section.dart';
import 'package:everglow/features/dashboard/presentation/widgets/metric_card.dart';
import 'package:everglow/features/xp/domain/models/user_progress.dart';
import 'package:everglow/features/xp/presentation/widgets/xp_progress_bar.dart';

void main() {
  testWidgets('dashboard primitives render without layout errors', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                const FeatureSection(
                  icon: Icons.event_rounded,
                  hue: AppColors.warmAmber,
                  title: 'Coming Up',
                  subtitle: 'no dates planned yet',
                  trailing: Icon(Icons.chevron_right_rounded),
                  child: SizedBox(height: 40),
                ),
                const MetricCard(label: 'Days', value: 29),
                XPProgressBar(
                  progress: UserProgress(
                    uid: 'test',
                    level: 3,
                    xpTotal: 2450,
                    streak: 0,
                    lastActivity: DateTime.now(),
                  ),
                ),
                const SizedBox(height: 200),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Coming Up'), findsOneWidget);
    expect(find.text('29'), findsOneWidget);
    expect(find.text('LEVEL 3'), findsOneWidget);
  });
}
