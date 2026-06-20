import 'package:flutter/material.dart';

/// Dusk Petal v2 — Breakpoint token system.
///
/// Provides responsive breakpoint constants and helpers.
/// Use `AppBreakpoint.of(context)` to get the current breakpoint.
class AppBreakpoint {
  AppBreakpoint._();

  static const double mobile  = 600;
  static const double tablet  = 1024;
  static const double desktop = 1440;

  /// Returns the current breakpoint category.
  static BreakpointSize of(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= tablet) return BreakpointSize.desktop;
    if (width >= mobile) return BreakpointSize.tablet;
    return BreakpointSize.mobile;
  }

  /// Whether the current viewport is mobile (< 600px).
  static bool isMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < mobile;

  /// Whether the current viewport is tablet (600–1023px).
  static bool isTablet(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return w >= mobile && w < tablet;
  }

  /// Whether the current viewport is desktop (≥ 1024px).
  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= tablet;
}

enum BreakpointSize { mobile, tablet, desktop }

/// Responsive padding widget — wraps child with appropriate
/// horizontal padding based on viewport width.
class ResponsivePadding extends StatelessWidget {
  final Widget child;
  final double? mobile;
  final double? tablet;
  final double? desktop;

  const ResponsivePadding({
    super.key,
    required this.child,
    this.mobile  = 16,
    this.tablet  = 32,
    this.desktop = 48,
  });

  @override
  Widget build(BuildContext context) {
    final bp = AppBreakpoint.of(context);
    final h = switch (bp) {
      BreakpointSize.mobile  => mobile  ?? 16,
      BreakpointSize.tablet  => tablet  ?? 32,
      BreakpointSize.desktop => desktop ?? 48,
    };
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: h),
      child: child,
    );
  }
}

/// Responsive value picker — returns [mobile], [tablet], or [desktop]
/// based on the current viewport.
class ResponsiveValue<T> {
  final T mobile;
  final T tablet;
  final T desktop;

  const ResponsiveValue({
    required this.mobile,
    required this.tablet,
    required this.desktop,
  });

  T of(BuildContext context) {
    final bp = AppBreakpoint.of(context);
    return switch (bp) {
      BreakpointSize.mobile  => mobile,
      BreakpointSize.tablet  => tablet,
      BreakpointSize.desktop => desktop,
    };
  }
}
