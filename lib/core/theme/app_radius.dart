import 'package:flutter/material.dart';

class AppRadius {
  AppRadius._();

  static const double xs = 8;
  static const double sm = 12;
  static const double md = 14;
  static const double lg = 16;
  static const double xl = 20;
  static const double x2 = 24;
  static const double x3 = 28;
  static const double full = 999;

  static BorderRadius get radiusXs => BorderRadius.circular(xs);
  static BorderRadius get radiusSm => BorderRadius.circular(sm);
  static BorderRadius get radiusMd => BorderRadius.circular(md);
  static BorderRadius get radiusLg => BorderRadius.circular(lg);
  static BorderRadius get radiusXl => BorderRadius.circular(xl);
  static BorderRadius get radiusX2 => BorderRadius.circular(x2);
  static BorderRadius get radiusX3 => BorderRadius.circular(x3);
  static BorderRadius get radiusFull => BorderRadius.circular(full);

  static RoundedRectangleBorder get shapeX2 =>
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(x2));
  static RoundedRectangleBorder get shapeXl =>
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(xl));
  static RoundedRectangleBorder get shapeMd =>
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(md));
}
