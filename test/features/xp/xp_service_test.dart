import 'package:flutter_test/flutter_test.dart';
import 'package:everglow/features/xp/data/services/xp_service.dart';

void main() {
  group('XpAward definitions', () {
    test('mood award gives 20 XP with daily cap 1', () {
      expect(XPService.moodAward.amount, 20);
      expect(XPService.moodAward.dailyCap, 1);
    });

    test('journal award gives 30 XP with daily cap 2', () {
      expect(XPService.journalAward.amount, 30);
      expect(XPService.journalAward.dailyCap, 2);
    });

    test('garden award gives 10 XP with daily cap 1', () {
      expect(XPService.gardenAward.amount, 10);
      expect(XPService.gardenAward.dailyCap, 1);
    });

    test('star award gives 15 XP with daily cap 3', () {
      expect(XPService.starAward.amount, 15);
      expect(XPService.starAward.dailyCap, 3);
    });

    test('listen award gives 2 XP with daily cap 30', () {
      expect(XPService.listenAward.amount, 2);
      expect(XPService.listenAward.dailyCap, 30);
    });

    test('play award gives 3 XP with daily cap 20', () {
      expect(XPService.playAward.amount, 3);
      expect(XPService.playAward.dailyCap, 20);
    });

    test('dedicate award gives 15 XP with daily cap 5', () {
      expect(XPService.dedicateAward.amount, 15);
      expect(XPService.dedicateAward.dailyCap, 5);
    });
  });

  group('XPService singleton and helpers', () {
    test('singleton returns the same instance', () {
      final a = XPService();
      final b = XPService();
      expect(identical(a, b), isTrue);
    });

    test('todayKey formats dates with zero padding', () {
      final date = DateTime(2026, 3, 5);
      expect(XPService.todayKey(date), '2026-03-05');

      final dateLate = DateTime(2026, 12, 25);
      expect(XPService.todayKey(dateLate), '2026-12-25');
    });
  });
}
