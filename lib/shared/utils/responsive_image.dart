import 'dart:async';

import 'package:flutter/widgets.dart';

/// Responsive decode width for a full-bleed hero/backdrop image.
///
/// Caps at 800px on phones (was hardcoded 900–1280 everywhere, decoding
/// 3x the pixels a 400px phone can show) and 1280px on desktop.
int heroCacheWidth(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  final dpr = MediaQuery.devicePixelRatioOf(context);
  final isDesktop = width >= 900;
  final target = isDesktop ? 1280.0 : 800.0;
  final w = width * dpr;
  if (w <= 0) return target.round();
  return (w > target ? target : w).clamp(400.0, target).round();
}

/// Debounced one-shot search helper: memoizes the latest future so a
/// rebuild doesn't refire the query, and ignores stale completions.
class DebouncedSearch<T> {
  DebouncedSearch({this.delay = const Duration(milliseconds: 300)});

  final Duration delay;
  Timer? _timer;
  Future<T>? current;
  int _version = 0;

  void run(Future<T> Function() query, void Function() onUpdate) {
    _timer?.cancel();
    _timer = Timer(delay, () {
      _version++;
      current = query();
      onUpdate();
    });
  }

  int get version => _version;

  void dispose() => _timer?.cancel();
}
