// Conditional export: native uses http streaming, web uses XHR streaming.
export 'sse_streamer_native.dart'
    if (dart.library.html) 'sse_streamer_web.dart';
