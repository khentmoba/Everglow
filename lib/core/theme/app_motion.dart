import 'package:flutter/material.dart';

import '../perf/device_capability.dart';
import '../theme/app_theme.dart';

class AppMotion {
  AppMotion._();

  static const Curve easeOutStrong = Cubic(0.23, 1.0, 0.32, 1.0);

  static const Curve easeOutExpo = Cubic(0.16, 1.0, 0.3, 1.0);

  static const Curve drawer = Cubic(0.32, 0.72, 0.0, 1.0);

  static const Curve easeOutQuint = Cubic(0.22, 1.0, 0.36, 1.0);

  static const Duration fast = Duration(milliseconds: 160);

  static const Duration medium = Duration(milliseconds: 220);

  static const Duration page = Duration(milliseconds: 320);

  static const Duration reveal = Duration(milliseconds: 400);

  static const Duration carousel = Duration(milliseconds: 700);

  static const Duration carouselHold = Duration(seconds: 20);

  static const Duration carouselHoldTrailer = Duration(seconds: 30);

  static bool get reduced => AppTheme.shouldReduceMotion;

  static bool reduceAmbientMotion(BuildContext context) =>
      reduced ||
      MediaQuery.disableAnimationsOf(context) ||
      MediaQuery.sizeOf(context).shortestSide < 600 ||
      DeviceCapability.isLowEndDevice;

  static Duration orZero(Duration duration) =>
      reduced ? Duration.zero : duration;

  static Curve orLinear(Curve curve) => reduced ? Curves.linear : curve;

  static const double pressScale = 0.96;

  static const double hoverLift = -4.0;

  static const double hoverScale = 1.03;
}
