// Web builds use the fetch/XHR SSE client, which delivers real incremental
// chunks across browsers (including older iOS/embedded webviews where
// fetch-based body streams buffer). VM builds use the native HTTP streamer.
export 'sse_streamer_web.dart' if (dart.library.io) 'sse_streamer_native.dart';
