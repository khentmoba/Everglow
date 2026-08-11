import 'package:flutter_test/flutter_test.dart';
import 'package:everglow/core/theme/app_theme.dart';
import 'package:everglow/core/theme/app_colors.dart';

void main() {
  group('AppTheme tokens', () {
    test('glassOpacity is 0.12', () {
      expect(AppTheme.glassOpacity, 0.12);
    });

    test('petalFieldOpacity is 0.08', () {
      expect(AppTheme.petalFieldOpacity, 0.08);
    });

    test('color tokens delegate to AppColors', () {
      expect(AppTheme.roseQuartz, AppColors.roseQuartz);
      expect(AppTheme.deepRose, AppColors.deepRose);
      expect(AppTheme.blushGold, AppColors.blushGold);
      expect(AppTheme.twilight, AppColors.twilight);
      expect(AppTheme.velvet, AppColors.velvet);
      expect(AppTheme.petalWhite, AppColors.petalWhite);
      expect(AppTheme.softLavender, AppColors.softLavender);
      expect(AppTheme.moonlight, AppColors.moonlight);
    });
  });

  group('AppColors semantic roles', () {
    test('textHigh is near-white', () {
      expect(AppColors.textHigh.alpha, greaterThan(200));
    });

    test('textDisabled is significantly transparent', () {
      expect(AppColors.textDisabled.alpha, lessThan(120));
    });

    test('border is transparent', () {
      expect(AppColors.border.alpha, lessThan(60));
    });
  });
}