:: Everglow production build — forces GPU-accelerated CanvasKit renderer
:: No source maps for prod (smaller payload, no leak of original Dart sources).
:: For debugging, use build_staging.bat which keeps maps.
flutter build web --web-renderer canvaskit --release --no-source-maps
