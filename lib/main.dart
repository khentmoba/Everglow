import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

import 'core/agent/agent_hud.dart';
import 'core/agent/agent_mode.dart';
import 'core/di/app_providers.dart';
import 'core/di/app_root.dart';
import 'core/perf/perf_hud.dart';
import 'core/perf/perf_settings.dart';
import 'core/router/app_router.dart';
import 'core/router/route_memory.dart';
import 'shared/utils/scroll_memory.dart';
import 'core/services/notification_service.dart';
import 'core/system/app_bootstrap.dart';
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
  // Dev tooling flags (`?perf=1`, `?dpr=2`, or a previously saved switch).
  // Before runApp on purpose: the engine caches the view's physical size at
  // the first frame, so a render-scale override has to land first. The frame
  // meter also mirrors its numbers to `window.__everglowPerf` on web, which is
  // how tool/perf/measure_scroll.mjs measures a build instead of eyeballing it.
  await PerfSettings.load();

  // Agent sandbox mode (`?agent=1`, `?agent=khent`, `?agent=cinema`, or local dev).
  // Initialized before router and first frame so deep links work without bouncing.
  await AgentMode.init();
  if (AgentMode.isActive.value) {
    authService.enableAgentSession(profile: AgentMode.activeProfile.value);
  }

  // Bound the decoded-image cache before the first frame.
  //
  // Flutter's default is 1000 images / 100 MB, but that 1000-object count is
  // the binding limit: with `AppNetworkImage` decoding every poster to ~400 px
  // (≈0.96 MB each) a long browsing session can hold ~1 GB of decoded
  // bitmaps, which is more than Clair's phone can give back to the OS. A
  // byte-based ceiling evicts by real cost instead, and the smaller object
  // count keeps the pending/keep-alive bookkeeping cheap.
  PaintingBinding.instance.imageCache
    ..maximumSize = 220
    ..maximumSizeBytes = 96 << 20; // 96 MB of decoded bitmaps
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
        title: 'Everglow',
        debugShowCheckedModeBanner: false,
        theme: custom_theme.AppTheme.gamifiedTheme,
        routerConfig: createAppRouter(),
        scaffoldMessengerKey: _scaffoldMessengerKey,
        builder: (context, child) => PerfMeterOverlay(
          child: AgentHudOverlay(
            child: AppUpdatePrompt(child: AppRoot(child: child!)),
          ),
        ),
      ),
    );
  }
}
