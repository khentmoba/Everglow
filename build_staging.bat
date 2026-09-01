:: Everglow staging build — same as prod but with source maps for debugging
:: Keeps main.dart.js.map so stack traces map to Dart sources. Deploy to a
:: staging/preview channel, not live. Use: firebase hosting:channel:deploy staging
flutter build web --release --source-maps
