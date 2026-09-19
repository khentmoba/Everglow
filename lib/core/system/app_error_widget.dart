import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Release fallback shown when a widget build crashes.
///
/// Web release: a transparent card with a retry tap instead of the opaque
/// grey [ErrorWidget] box. The builder itself is guarded so it can never
/// throw (a throwing builder recurses into ErrorWidget and blows the JS
/// stack — the grey "Something went dark" overlay seen in the Together
/// zone). Kept minimal and non-selectable on purpose.
Widget buildEverglowErrorWidget(FlutterErrorDetails details) {
  // Guard the builder itself — if *this* throws, Flutter will recurse
  // into ErrorWidget again and blow the JS stack (RangeError: Maximum
  // call stack size exceeded) which is exactly the grey "Something went
  // dark" overlay seen in the Together zone. Keep it minimal and
  // non-selectable so it can never throw.
  String msg;
  String shortStack;
  String widgetName = 'widget';
  try {
    msg = details.exceptionAsString();
  } catch (_) {
    msg = 'Unknown error';
  }
  try {
    final stack = details.stack?.toString() ?? '';
    shortStack = stack.length > 400 ? stack.substring(0, 400) : stack;
  } catch (_) {
    shortStack = '';
  }
  try {
    widgetName = details.context?.toString() ?? 'widget';
    if (widgetName.length > 50) widgetName = '${widgetName.substring(0, 50)}…';
  } catch (_) {}
  if (kDebugMode) {
    return ErrorWidget(details.exception);
  }
  // In release, keep background transparent so dashboard inkDeep shows
  // through. Never use SelectableText with an unbounded stack trace —
  // on CanvasKit it can re-enter layout and trigger the same Stack
  // Overflow. Use plain Text with ellipsis and a constrained scroll.
  return Material(
    type: MaterialType.transparency,
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360, maxHeight: 340),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.velvet.withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.roseQuartz.withValues(alpha: 0.15),
            ),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.cloud_off_rounded,
                  color: AppColors.roseQuartz,
                  size: 28,
                ),
                const SizedBox(height: 8),
                Text(
                  'Something went dark — $widgetName — tap to retry',
                  style: const TextStyle(
                    color: AppColors.petalWhite,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  msg.length > 180 ? '${msg.substring(0, 180)}…' : msg,
                  style: TextStyle(
                    color: AppColors.roseQuartz.withValues(alpha: 0.85),
                    fontSize: 11.5,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                if (shortStack.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    shortStack,
                    style: TextStyle(
                      color: AppColors.petalWhite.withValues(alpha: 0.65),
                      fontSize: 10,
                      height: 1.35,
                    ),
                    textAlign: TextAlign.left,
                    maxLines: 6,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () {
                    // Retry is best-effort: reassemble, then force a frame.
                    // (A real web reload via JS interop was considered here
                    // but never wired up — both paths always reassembled.)
                    try {
                      WidgetsBinding.instance.reassembleApplication();
                    } catch (_) {}
                    // As a last resort, schedule a warm-up frame to
                    // trigger a rebuild of the widget tree.
                    Future.microtask(() {
                      try {
                        WidgetsBinding.instance.scheduleWarmUpFrame();
                      } catch (_) {}
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.deepRose.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'Retry',
                      style: TextStyle(
                        color: AppColors.petalWhite,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
