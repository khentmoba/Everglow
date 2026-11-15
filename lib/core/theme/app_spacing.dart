import 'package:flutter/material.dart';

class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double x2 = 24;
  static const double x3 = 32;
  static const double x4 = 48;
  static const double x5 = 64;
  static const double x6 = 80;

  static double section(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= 1024) return x6;
    if (width >= 600) return x5;
    return x4;
  }

  static double pageH(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= 1024) return x4;
    if (width >= 600) return x3;
    return lg;
  }

  static EdgeInsets pageHorizontal(BuildContext context) =>
      EdgeInsets.symmetric(horizontal: pageH(context));

  static EdgeInsets sectionVertical(BuildContext context) =>
      EdgeInsets.symmetric(vertical: section(context));

  static const EdgeInsets card = EdgeInsets.all(x2);

  static const EdgeInsets cardCompact = EdgeInsets.all(lg);
}
