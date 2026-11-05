import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'features/cinema/data/services/cinema_home_cache.dart';
import 'shared/utils/scroll_memory.dart';
import 'core/services/notification_service.dart';
import 'core/system/app_bootstrap.dart';
import 'core/system/app_error_widget.dart';
import 'core/system/app_version.dart';
import 'core/system/health_service.dart';
import 'core/theme/app_theme.dart' as custom_theme;
import 'core/network/network_quality_service.dart';
import 'core/perf/device_capability.dart';
import 'core/utils/connectivity_service.dart';
import 'core/utils/logger.dart';
import 'firebase_options.dart';
import 'shared/widgets/everglow/app_update_prompt.dart';

/// Global key for SnackBar notifications.
final _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// Never takes focus, so keys like Escape still reach the open dialog.
/// Ctrl+C still works: the dialog sits inside this area's actions.
final _popupSelectionFocus = FocusNode(
  canRequestFocus: false,
  skipTraversal: true,
);

void main() {
  runZonedGuarded(_startEverglow, _zoneErrorHandler);
}

Future<void> _startEverglow() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Bound the decoded-image cache immediately so early decodes follow bounds.
  final isLowEnd = DeviceCapability.isLowEndDevice;
  PaintingBinding.instance.imageCache
    ..maximumSize = isLowEnd ? 100 : 220
    ..maximumSizeBytes = isLowEnd ? (48 << 20) : (96 << 20);

  // On web, disable the native browser context menu so Flutter's SelectionArea
  // can display its adaptive context menu toolbar ("Copy", "Select all") on
  // right-click / long-press and copy selected text to the clipboard.
  // Non-blocking: never delay first frame for platform menu state.
  if (kIsWeb) {
    unawaited(BrowserContextMenu.disableContextMenu());
  }

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

  // Initialize connectivity & network quality monitoring.
  ConnectivityService.instance.init();
  NetworkQualityService.instance.init();

  final bootstrap = AppBootstrap(
    loadEnvironment: () => dotenv.load(fileName: 'assets/env.txt'),
    initializeFirebase: () async {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    },
    initializeNotifications: () => NotificationService.instance.initialize(),
    scaffoldMessengerKey: _scaffoldMessengerKey,
    probeHealth: () => HealthService(
      isOnline: () => ConnectivityService.instance.isOnline,
    ).probe(),
  );

  // Dev tooling flags, agent mode, and preloaded route/scroll states:
  // load concurrently in parallel with bootstrap so startup is not serialized.
  final preloadsFuture = Future.wait([
    PerfSettings.load(),
    AgentMode.init(),
    RouteMemory.load(),
    ScrollMemory.preload(),
    // Cinema paints saved rows on its first frame instead of after a read.
    CinemaHomeCache.warm(),
  ]);

  final bootstrapFuture = bootstrap.run();

  final results = await Future.wait([
    bootstrapFuture,
    preloadsFuture,
  ]);
  final result = results[0] as BootstrapResult;

  Logger.i(
    'Everglow ${AppVersion.current} ready in '
    '${result.elapsed.inMilliseconds}ms',
  );

  if (AgentMode.isActive.value) {
    authService.enableAgentSession(profile: AgentMode.activeProfile.value);
  }

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
            child: AppUpdatePrompt(
              // Pages get their own SelectionArea (app_router's ShellRoute).
              // This outer one covers dialogs and sheets, which open above
              // it; Overlay.wrap gives their Copy menu somewhere to float.
              child: AppRoot(
                child: Overlay.wrap(
                  child: SelectionArea(
                    focusNode: _popupSelectionFocus,
                    child: child!,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
