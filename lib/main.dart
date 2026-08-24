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
