import 'package:everglow/features/heartbeat/data/models/user_mood.dart';
import 'package:everglow/features/heartbeat/data/services/mood_service.dart';
import 'package:everglow/features/heartbeat/presentation/controllers/mood_controller.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeMoodSource extends MoodSource {
  bool submittedToday = false;
  int submits = 0;
  Object? submitError;

  @override
  Future<bool> hasSubmittedToday(String username) async => submittedToday;

  @override
  Future<void> submitMood({
    required String username,
    required int score,
    required String emoji,
  }) async {
    submits++;
    if (submitError != null) throw submitError!;
  }

  @override
  Future<UserMood?> getLatestMood(String username) async => null;

  @override
  Stream<UserMood?> watchLatestMood(String username) =>
      const Stream.empty();
}

void main() {
  group('MoodController', () {
    test('checkTodayStatus reflects the service answer', () async {
      final fake = FakeMoodSource()..submittedToday = true;
      final controller = MoodController(fake);

      await controller.checkTodayStatus('clair');

      expect(controller.hasSubmittedToday, isTrue);
    });

    test('submitMood marks today done and closes check-in', () async {
      final fake = FakeMoodSource();
      final controller = MoodController(fake);
      controller.startCheckIn();

      await controller.submitMood(
        username: 'clair',
        score: 5,
        emoji: '🥰',
      );

      expect(fake.submits, 1);
      expect(controller.selectedScore, 5);
      expect(controller.hasSubmittedToday, isTrue);
      expect(controller.isCheckingIn, isFalse);
    });

    test('submitMood lets Clair retry when saving fails', () async {
      final fake = FakeMoodSource()..submitError = Exception('offline');
      final controller = MoodController(fake);
      controller.startCheckIn();

      await controller.submitMood(
        username: 'clair',
        score: 4,
        emoji: '😊',
      );

      expect(fake.submits, 1);
      expect(controller.selectedScore, isNull);
      expect(controller.hasSubmittedToday, isFalse);
      expect(controller.isCheckingIn, isTrue);
    });
  });
}
