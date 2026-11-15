import 'package:flutter/widgets.dart';

class WebStandalone {
  WebStandalone._();

  static bool isStandalone() => false;

  static void openPaintControl() {}

  static String viewportReport() => 'Screen measurement is available on web.';

  static double safeAreaTop() => 0;

  static EdgeInsets safeAreaPadding() => EdgeInsets.zero;
  static double keyboardInset() => 0;

  @visibleForTesting
  static EdgeInsets probeSafeAreaPadding() => EdgeInsets.zero;

  @visibleForTesting
  static double probeSafeAreaTop() => 0;
}

class WebStandaloneInsets extends StatelessWidget {
  final Widget child;

  const WebStandaloneInsets({super.key, required this.child});

  @override
  Widget build(BuildContext context) => child;
}
