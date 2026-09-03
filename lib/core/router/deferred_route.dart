import "package:flutter/material.dart";

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
class DeferredRouteLoader extends StatefulWidget {
  /// Deferred prefix tear-off, e.g. `chessLib.loadLibrary`.
  final Future<void> Function() loadLibrary;

  /// Builds the real screen. Only called after the chunk loads.
  final Widget Function() builder;

  /// Short human label used in loading/error UI, e.g. "Chess".
  final String label;

  const DeferredRouteLoader({
    super.key,
    required this.loadLibrary,
    required this.builder,
    required this.label,
  });

  @override
  State<DeferredRouteLoader> createState() => _DeferredRouteLoaderState();
}

class _DeferredRouteLoaderState extends State<DeferredRouteLoader> {
  late Future<void> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.loadLibrary();
  }

  void _retry() {
    setState(() {
      _future = widget.loadLibrary();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return _LoadingBody(label: widget.label);
        }
        if (snapshot.hasError) {
          return _ErrorBody(label: widget.label, onRetry: _retry);
        }
        return widget.builder();
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