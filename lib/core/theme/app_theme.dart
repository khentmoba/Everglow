import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_typography.dart';
import 'app_radius.dart';

class AppTheme {
  AppTheme._();

  static const Color roseQuartz = AppColors.roseQuartz;
  static const Color deepRose = AppColors.deepRose;
  static const Color blushGold = AppColors.blushGold;
  static const Color twilight = AppColors.twilight;
  static const Color velvet = AppColors.velvet;
  static const Color petalWhite = AppColors.petalWhite;
  static const Color softLavender = AppColors.softLavender;
  static const Color warmAmber = AppColors.warmAmber;
  static const Color moonlight = AppColors.moonlight;

  static const LinearGradient gamifiedGradient = LinearGradient(
    colors: [AppColors.twilight, AppColors.velvet, AppColors.deepRose],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient duskGradient = LinearGradient(
    colors: [AppColors.inkDeep, AppColors.twilight, AppColors.velvet],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient roseGoldGradient = LinearGradient(
    colors: [AppColors.auroraRose, AppColors.deepRose, AppColors.blushGold],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient lilacWash = LinearGradient(
    colors: [AppColors.softLavender, AppColors.moonlight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const double glassBlur = 18.0;
  static const double glassOpacity = 0.08;

  static ThemeData get gamifiedTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.deepRose,
        primary: AppColors.deepRose,
        secondary: AppColors.softLavender,
        tertiary: AppColors.blushGold,
        surface: AppColors.twilight,
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: AppColors.twilight,
      fontFamily: AppTypography.body,
      fontFamilyFallback: AppTypography.fontFallback,
      textTheme: AppTypography.textTheme,
      iconTheme: const IconThemeData(color: AppColors.petalWhite),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.petalWhite,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.panelGlass,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.radiusX2,
          side: BorderSide(color: AppColors.border),
        ),
        barrierColor: AppColors.inkDeep.withValues(alpha: 0.72),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppColors.velvet,
        modalBarrierColor: AppColors.inkDeep.withValues(alpha: 0.72),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.x2),
          ),
        ),
        showDragHandle: true,
        dragHandleColor: AppColors.moonlight.withValues(alpha: 0.35),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.velvet,
        contentTextStyle: AppTypography.bodyMedium(),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.radiusLg,
          side: BorderSide(color: AppColors.border),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.roseQuartz,
        unselectedLabelColor: AppColors.textMuted,
        indicatorColor: AppColors.deepRose,
        dividerColor: AppColors.divider,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceGlass,
        side: BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusFull),
        labelStyle: AppTypography.titleSmall(),
      ),
      dividerTheme: DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
        space: 1,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.deepRose,
        foregroundColor: AppColors.petalWhite,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.inkDeep.withValues(alpha: 0.95),
          borderRadius: AppRadius.radiusMd,
          border: Border.all(color: AppColors.border),
        ),
        textStyle: AppTypography.bodySmall(),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: AppColors.deepRose,
        selectionColor: AppColors.deepRose.withValues(alpha: 0.28),
        selectionHandleColor: AppColors.deepRose,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.deepRose,
        linearTrackColor: Color(0x1FF0E6FF),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.petalWhite
              : AppColors.textDisabled,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.deepRose
              : AppColors.moonlight.withValues(alpha: 0.16),
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.deepRose
              : Colors.transparent,
        ),
        side: BorderSide(color: AppColors.moonlight.withValues(alpha: 0.4)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.deepRose
              : AppColors.textMuted,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surfaceGlass,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.radiusX2,
          side: BorderSide(color: AppColors.border, width: 1.0),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.deepRose,
          foregroundColor: AppColors.petalWhite,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusX2),
          textStyle: AppTypography.labelLarge(),
        ),
      ),
    );
  }

  static bool get shouldReduceMotion => WidgetsBinding
      .instance
      .platformDispatcher
      .accessibilityFeatures
      .reduceMotion;
  static const double petalFieldOpacity = 0.08;
}
