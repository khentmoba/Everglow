import 'package:flutter/material.dart';

class AppBreakpoint {
  AppBreakpoint._();

  static const double mobile = 600;
  static const double tablet = 1024;
  static const double desktop = 1440;

  static BreakpointSize of(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= tablet) return BreakpointSize.desktop;
    if (width >= mobile) return BreakpointSize.tablet;
    return BreakpointSize.mobile;
  }

  static bool isMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < mobile;

  static bool isTablet(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return w >= mobile && w < tablet;
  }

  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= tablet;
}

enum BreakpointSize { mobile, tablet, desktop }

class ResponsivePadding extends StatelessWidget {
  final Widget child;
  final double? mobile;
  final double? tablet;
  final double? desktop;

  const ResponsivePadding({
    super.key,
    required this.child,
    this.mobile = 16,
    this.tablet = 32,
    this.desktop = 48,
  });

  @override
  Widget build(BuildContext context) {
    final bp = AppBreakpoint.of(context);
    final h = switch (bp) {
      BreakpointSize.mobile => mobile ?? 16,
      BreakpointSize.tablet => tablet ?? 32,
      BreakpointSize.desktop => desktop ?? 48,
    };
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: h),
      child: child,
    );
  }
}

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
      BreakpointSize.mobile => mobile,
      BreakpointSize.tablet => tablet,
      BreakpointSize.desktop => desktop,
    };
  }
}
