// Use the native HTTP streamer on all platforms.
// The dart:html HttpRequest wrapper does not reliably
// support incremental responseText during streaming.
export 'sse_streamer_native.dart';
