import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

import 'core/di/app_providers.dart';
import 'core/di/app_root.dart';
import 'core/perf/perf_hud.dart';
import 'core/perf/perf_settings.dart';
import 'core/router/app_router.dart';
import 'core/router/route_memory.dart';
import 'shared/utils/scroll_memory.dart';
import 'core/services/notification_service.dart';
import 'core/system/app_bootstrap.dart';
import 'core/system/app_check.dart';
import 'core/system/app_error_widget.dart';
import 'core/system/app_version.dart';
import 'core/system/health_service.dart';
import 'core/theme/app_theme.dart' as custom_theme;
import 'core/utils/connectivity_service.dart';
import 'core/utils/logger.dart';
import 'firebase_options.dart';
import 'shared/widgets/everglow/app_update_prompt.dart';

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
    Logger.e(
      '[FlutterError at $widgetName]',
      error: details.exception,
      stackTrace: details.stack,
    );
  };
  ErrorWidget.builder = buildEverglowErrorWidget;

  // Initialize connectivity monitoring for offline-aware error handling.
  ConnectivityService.instance.init();

  final bootstrap = AppBootstrap(
    loadEnvironment: () => dotenv.load(fileName: 'assets/env.txt'),
    initializeFirebase: () async {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      try {
        await activateAppCheck();
      } catch (e) {
        Logger.e('[AppCheck] activation failed', error: e);
      }
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
    '${result.elapsed.inMilliseconds}ms',
  );
  // Dev tooling flags (`?perf=1`, `?dpr=2`, or the saved Creator Studio
  // switches). Before runApp on purpose: the engine caches the view's physical
  // size at the first frame, so a render-scale override has to land first.
  await PerfSettings.load();
  // Remembered page for this device (route_memory.dart): ready before the
  // router is created so a killed tab/PWA reopens where she left off.
  await RouteMemory.load();
  // Saved scroll spots (scroll_memory.dart): ready before the first
  // frame so long lists open exactly where she left them.
  await ScrollMemory.preload();
  // Health lands after first frame; log it when it arrives.
  unawaited(
    result.healthFuture.then(
      (health) => Logger.i('Everglow backend health: ${health.status}'),
    ),
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
      // Logger.e always emits (even in release) for the production trail.
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
        routerConfig: createAppRouter(),
        scaffoldMessengerKey: _scaffoldMessengerKey,
        builder: (context, child) => PerfMeterOverlay(
          child: AppUpdatePrompt(child: AppRoot(child: child!)),
        ),
      ),
    );
  }
}
