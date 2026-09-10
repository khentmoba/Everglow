// Custom Flutter web bootstrap (replaces the SDK default template).
//
// The default template registers Flutter's own service worker, which is a
// deprecated self-unregistering shim — and Everglow ships its own worker
// (web/sw.js, cache-first shell + immutable assets) registered from
// index.html. Two workers on the same scope would flap and reload-loop, so
// this bootstrap intentionally passes NO serviceWorkerSettings: Flutter
// never touches service workers and ours owns the scope alone.
//
// Placeholders below are substituted at build time by flutter_tools.
// Clean up deprecated Intl.v8BreakIterator ahead of Flutter's browser detection
// so it cleanly chooses standard CanvasKit ICU text segmentation instead of
// triggering Chrome's deprecation warning.
try {
  if (typeof window !== 'undefined' && window.Intl) {
    delete window.Intl.v8BreakIterator;
  }
} catch (_) {
  try { window.Intl.v8BreakIterator = undefined; } catch (__) {}
}
{{flutter_js}}
{{flutter_build_config}}
_flutter.loader.load({
  config: {
    canvasKitVariant: "full"
  }
});
