// Render-scale override is web-only: the native engines size their surface
// from the OS, and `dart:ui_web` only exists on web.
export 'render_scale_web.dart'
    if (dart.library.io) 'render_scale_stub.dart';
