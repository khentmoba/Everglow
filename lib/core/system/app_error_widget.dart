import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

Widget buildEverglowErrorWidget(FlutterErrorDetails details) {
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
                    try {
                      WidgetsBinding.instance.reassembleApplication();
                    } catch (_) {}
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
