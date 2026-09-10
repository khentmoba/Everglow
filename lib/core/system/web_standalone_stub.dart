import 'package:flutter/widgets.dart';

/// Non-browser fallback for [web_standalone_web.dart]: never applies an
/// inset, so native builds and VM tests render exactly as before.
class WebStandalone {
  WebStandalone._();

  static bool isStandalone() => false;

  static double safeAreaTop() => 0;

  @visibleForTesting
  static double probeSafeAreaTop() => 0;
}

/// Pass-through on non-web platforms: returns [child] untouched.
class WebAppTopInset extends StatelessWidget {
  final Widget child;

  const WebAppTopInset({super.key, required this.child});

  @override
  Widget build(BuildContext context) => child;
}
