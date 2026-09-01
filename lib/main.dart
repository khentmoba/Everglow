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
    Logger.e('[FlutterError]', error: details.exception, stackTrace: details.stack);
  };
  ErrorWidget.builder = (details) {
    final msg = details.exceptionAsString();
    final isReleaseGreyZone = msg.contains('Starlight') || msg.contains('Timeline') || msg.isNotEmpty;
    if (kDebugMode) {
      return ErrorWidget(details.exception);
    }
    // In release, keep background transparent so dashboard inkDeep shows through,
    // and log the error to console instead of painting opaque lightGrey.
    return Material(
      type: MaterialType.transparency,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF2D1B33).withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF4C2C2).withValues(alpha: 0.15)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, color: Color(0xFFF4C2C2), size: 28),
            const SizedBox(height: 8),
            Text(
              'Something went dark — tap to retry',
              style: TextStyle(color: const Color(0xFFFFF5F5).withValues(alpha: 0.8), fontSize: 12),
            ),
            if (!kReleaseMode || isReleaseGreyZone)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  msg.length > 180 ? msg.substring(0, 180) : msg,
                  style: TextStyle(color: const Color(0xFFF4C2C2).withValues(alpha: 0.6), fontSize: 9),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
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
