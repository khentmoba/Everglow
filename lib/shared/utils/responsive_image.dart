import 'dart:async';

import 'package:flutter/widgets.dart';

int heroCacheWidth(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  final dpr = MediaQuery.devicePixelRatioOf(context);
  final isDesktop = width >= 900;
  final target = isDesktop ? 1280.0 : 800.0;
  final w = width * dpr;
  if (w <= 0) return target.round();
  return (w > target ? target : w).clamp(400.0, target).round();
}

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
