import 'package:everglow/core/services/auth_service.dart';
import 'package:everglow/core/theme/app_theme.dart';
import 'package:everglow/features/guardian/presentation/controllers/guardian_controller.dart';
import 'package:everglow/features/heartbeat/data/models/user_mood.dart';
import 'package:everglow/features/heartbeat/data/services/mood_service.dart';
import 'package:everglow/features/heartbeat/presentation/controllers/mood_controller.dart';
import 'package:everglow/features/heartbeat/presentation/widgets/heart_emoji.dart';
import 'package:everglow/features/heartbeat/presentation/widgets/mood_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _Auth extends ChangeNotifier implements AuthService {
  @override
  String? get currentUser => 'khentsgdz';
  @override
  String get partnerName => 'Clair';
  @override
  String? get uid => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Guardian extends ChangeNotifier implements GuardianController {
  @override
  void dismissMoodPrompt() {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Moods implements MoodService {
  HeartNeed? savedNeed;
  Object? error;
  @override
  Stream<UserMood?> watchLatestMood(String username) => Stream.value(null);
  @override
  Future<void> submitMood({
    required String username,
    required int score,
    required String emoji,
    HeartNeed? need,
  }) async {
    if (error != null) throw error!;
    savedNeed = need;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _pump(WidgetTester tester, _Moods moods, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthService>(create: (_) => _Auth()),
        ChangeNotifierProvider<GuardianController>(create: (_) => _Guardian()),
        Provider<MoodService>.value(value: moods),
        ChangeNotifierProvider(create: (_) => MoodController(moods)),
      ],
      child: MaterialApp(
        theme: AppTheme.gamifiedTheme,
        home: const Scaffold(
          body: Stack(
            children: [Positioned(top: 132, right: 24, child: MoodPicker())],
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final size in [
    const Size(320, 700),
    const Size(430, 932),
    const Size(810, 932),
    const Size(810, 390),
  ]) {
    testWidgets('mood needs stay within the dashboard at $size', (
      tester,
    ) async {
      await _pump(tester, _Moods(), size);
      final bounds = tester.getRect(find.byType(MoodPicker));
      expect(bounds.left, greaterThanOrEqualTo(0));
      expect(bounds.right, lessThanOrEqualTo(size.width));
      expect(bounds.bottom, lessThanOrEqualTo(size.height));
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('the selected need saves with the mood', (tester) async {
    final moods = _Moods();
    await _pump(tester, moods, const Size(430, 932));
    await tester.tap(find.text('Need some quiet'));
    await tester.tap(find.byType(HeartEmoji).at(2));
    await tester.pumpAndSettle();
    expect(moods.savedNeed, HeartNeed.quiet);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'failed mood saves keep the need selected and show retry feedback',
    (tester) async {
      final moods = _Moods()..error = StateError('offline');
      await _pump(tester, moods, const Size(430, 932));
      await tester.tap(find.text('Want to talk'));
      await tester.tap(find.byType(HeartEmoji).at(2));
      await tester.pumpAndSettle();
      expect(
        find.text('Could not save your check-in. Please try again.'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Want to talk'))
            .selected,
        isTrue,
      );
      expect(moods.savedNeed, isNull);
      expect(tester.takeException(), isNull);
    },
  );
}
