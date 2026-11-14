import 'package:flutter/material.dart';

import '../network/network_quality_service.dart';
import '../perf/perf_probe.dart';
import '../perf/perf_settings.dart';
import '../utils/logger.dart';

/// Loading shell for routes split out of the initial bundle with
/// `deferred as` imports (see docs/PERF_NOTES.md).
///
/// Usage in a `go_router` builder:
/// ```dart
/// import "../screens/chess_game_screen.dart" deferred as chessLib;
///
/// GoRoute(
///   path: "chess",
///   builder: (_, _) => DeferredRouteLoader(
///     label: "Chess",
///     loadLibrary: chessLib.loadLibrary,
///     builder: () => chessLib.ChessGameScreen(),
///   ),
/// ),
/// ```
///
/// The chunk downloads on first navigation (~one small JS part file), then
/// stays cached for the session. Shows a themed spinner while loading and a
/// retry action if the chunk fails (offline mid-deploy, CDN hiccup).
///
/// [label] names the chunk: once a label has loaded, later visits build the
/// screen on the first frame instead of flashing the loading body for one.
/// Routes that share a label must share the same library.
class DeferredRouteLoader extends StatefulWidget {
  /// Deferred prefix tear-off, e.g. `chessLib.loadLibrary`.
  final Future<void> Function() loadLibrary;

  /// Builds the real screen. Only called after the chunk loads.
  final Widget Function() builder;

  /// Short human label used in loading/error UI, e.g. "Chess".
  final String label;

  /// Optional first paint while the chunk loads. Defaults to a spinner.
  final WidgetBuilder? loadingBuilder;

  const DeferredRouteLoader({
    super.key,
    required this.loadLibrary,
    required this.builder,
    required this.label,
    this.loadingBuilder,
  });

  @override
  State<DeferredRouteLoader> createState() => _DeferredRouteLoaderState();

  static final Set<String> _loaded = <String>{};

  /// Whether the chunk named [label] has finished loading this session.
  static bool isLoaded(String label) => _loaded.contains(label);

  /// Downloads a section's chunk before the first tap, so opening it does
  /// not wait on the network or flash the loading body.
  ///
  /// Skipped on a slow or data-saving connection, where the download would
  /// compete with the page Clair is actually looking at. Safe to call more
  /// than once: a loaded chunk resolves immediately.
  static Future<void> warm(
    String label,
    Future<void> Function() loadLibrary,
  ) async {
    if (_loaded.contains(label)) return;
    final network = NetworkQualityService.instance;
    if (network.isSlowConnection || network.isSaveData) return;
    try {
      await loadLibrary();
      _loaded.add(label);
    } catch (e, st) {
      Logger.w('$label: library warm-up failed', error: e, stackTrace: st);
    }
  }

  /// Forgets loaded chunks so widget tests start cold.
  @visibleForTesting
  static void debugReset() => _loaded.clear();
}

class _DeferredRouteLoaderState extends State<DeferredRouteLoader> {
  /// Null once the chunk is known to be loaded.
  Future<void>? _future;

  @override
  void initState() {
    super.initState();
    if (!DeferredRouteLoader.isLoaded(widget.label)) _future = _load();
  }

  Future<void> _load() async {
    await widget.loadLibrary();
    DeferredRouteLoader._loaded.add(widget.label);
  }

  void _retry() {
    setState(() {
      _future = _load();
    });
  }

  bool _marked = false;

  /// With the frame meter on, records when the real screen first painted so
  /// `tool/perf/probe_scroll.mjs --navigate` can time the tap-to-screen wait.
  Widget _screen() {
    if (!_marked && PerfSettings.frameMeter.value) {
      _marked = true;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => recordPerfMark('route:${widget.label}'),
      );
    }
    return widget.builder();
  }

  @override
  Widget build(BuildContext context) {
    if (_future == null) return _screen();
    return FutureBuilder<void>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return widget.loadingBuilder?.call(context) ??
              _LoadingBody(label: widget.label);
        }
        if (snapshot.hasError) {
          return _ErrorBody(label: widget.label, onRetry: _retry);
        }
        return _screen();
      },
    );
  }
}

class _LoadingBody extends StatelessWidget {
  final String label;

  const _LoadingBody({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(strokeWidth: 2.5),
            const SizedBox(height: 16),
            Text(
              "Loading $label…",
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.hintColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  final String label;
  final VoidCallback onRetry;

  const _ErrorBody({required this.label, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.cloud_off_rounded,
                size: 36,
                color: theme.hintColor,
              ),
              const SizedBox(height: 12),
              Text(
                "Couldn\u2019t load $label",
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                "Check your connection and try again.",
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.hintColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: onRetry,
                child: const Text("Retry"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}