:: Everglow production build — CanvasKit is default in current Flutter
:: No source maps for prod (smaller payload, no leak of original Dart sources).
:: For debugging, use build_staging.bat which keeps maps.
:: CanvasKit loads from the engine-pinned gstatic CDN when reachable
:: (tool/build_web.dart verifies, else falls back to self-hosted).
dart tool/generate_sw.dart
if errorlevel 1 exit /b 1
dart tool/build_web.dart -- --release --no-source-maps
