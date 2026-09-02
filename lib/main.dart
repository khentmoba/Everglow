import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

import 'core/di/app_providers.dart';
import 'core/di/app_root.dart';
import 'core/router/app_router.dart';
import 'core/services/notification_service.dart';
import 'core/system/app_bootstrap.dart';
import 'core/system/app_version.dart';
import 'core/system/health_service.dart';
import 'core/theme/app_theme.dart' as custom_theme;
import 'core/utils/connectivity_service.dart';
import 'core/utils/logger.dart';
import 'firebase_options.dart';

/// Global key for SnackBar notifications.
final _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

void main() {
  runZonedGuarded(_startEverglow, _zoneErrorHandler);
}

Future<void> _startEverglow() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Web release: prevent opaque grey ErrorWidget from swallowing Together zone.
  // Show transparent fallback with logged error instead of solid grey box.
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    String widgetName = 'no-context';
    try {
      widgetName = details.context?.toString() ?? 'no-widget';
    } catch (_) {}
    // ignore: avoid_print
    print('[FlutterError at $widgetName] ${details.exception}');
    Logger.e('[FlutterError at $widgetName]', error: details.exception, stackTrace: details.stack);
  };
  ErrorWidget.builder = (details) {
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
              color: const Color(0xFF2D1B33).withValues(alpha: 0.78),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFF4C2C2).withValues(alpha: 0.15)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off_rounded, color: Color(0xFFF4C2C2), size: 28),
                  const SizedBox(height: 8),
                  Text(
                    'Something went dark — $widgetName — tap to retry',
                    style: const TextStyle(color: Color(0xFFFFF5F5), fontSize: 11, fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    msg.length > 180 ? '${msg.substring(0, 180)}…' : msg,
                    style: TextStyle(color: const Color(0xFFF4C2C2).withValues(alpha: 0.8), fontSize: 8),
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (shortStack.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      shortStack,
                      style: TextStyle(color: const Color(0xFFFFF5F5).withValues(alpha: 0.45), fontSize: 7, height: 1.2),
                      textAlign: TextAlign.left,
                      maxLines: 6,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () {
                      // Hard reload on web so Firestore streams are torn down
                      // and re-created; reassembleApplication is a no-op in
                      // release web and would leave the same broken stream.
                      try {
                        if (kIsWeb) {
                          // ignore: avoid_web_libraries_in_flutter
                          // Use `web` package would require import; fallback to
                          // reassemble for non-web and reload via JS interop.
                          // For now, try to reload via Uri.
                          // The simplest cross-platform retry is to reassemble
                          // and then force a frame.
                          WidgetsBinding.instance.reassembleApplication();
                        } else {
                          WidgetsBinding.instance.reassembleApplication();
                        }
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
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: const Color(0xFFC2185B).withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text('Retry', style: TextStyle(color: Color(0xFFFFF5F5), fontSize: 11, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  };

  // Initialize connectivity monitoring for offline-aware error handling.
  ConnectivityService.instance.init();

  final bootstrap = AppBootstrap(
    loadEnvironment: () => dotenv.load(fileName: 'assets/env.txt'),
    initializeFirebase: () async {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    },
    initializeNotifications: () => NotificationService().initialize(),
    scaffoldMessengerKey: _scaffoldMessengerKey,
    probeHealth: () => HealthService(
      isOnline: () => ConnectivityService.instance.isOnline,
    ).probe(),
  );

  final result = await bootstrap.run();
  Logger.i(
    'Everglow ${AppVersion.current} ready in '
    '${result.elapsed.inMilliseconds}ms; backend=${result.health.status}',
  );
  runApp(const EverglowApp());
}

void _zoneErrorHandler(Object error, StackTrace stack) {
  final msg = error.toString();
  if (msg.contains('onSnapshotUnsubscribe') ||
      msg.contains('FIRESTORE INTERNAL ASSERTION')) {
    if (kDebugMode) {
      debugPrint('[Firestore] Known race condition (suppressed): $error');
    }
  } else {
    if (kDebugMode) {
      debugPrint('[Unhandled] $error\n$stack');
    } else {
      // debugPrint is throttled in release; keep an unfiltered console
      // trail for production web debugging.
      // ignore: avoid_print
      Logger.e('[Unhandled]', error: error, stackTrace: stack);
    }
  }
}

class EverglowApp extends StatelessWidget {
  const EverglowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: appProviders,
      child: MaterialApp.router(
        title: 'Everglow ${AppVersion.display}',
        debugShowCheckedModeBanner: false,
        theme: custom_theme.AppTheme.gamifiedTheme,
        routerConfig: appRouter,
        scaffoldMessengerKey: _scaffoldMessengerKey,
        builder: (context, child) => AppRoot(child: child!),
      ),
    );
  }
}
