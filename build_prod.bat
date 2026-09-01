:: Everglow production build — CanvasKit is default in current Flutter
:: No source maps for prod (smaller payload, no leak of original Dart sources).
:: For debugging, use build_staging.bat which keeps maps.
flutter build web --release --no-source-maps
