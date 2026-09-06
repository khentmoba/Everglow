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
{{flutter_js}}
{{flutter_build_config}}
_flutter.loader.load();
