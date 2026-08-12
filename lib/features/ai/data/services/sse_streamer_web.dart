// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
// Web-only SSE streaming client.
//
// Primary path: `fetch` + `ReadableStream` (incremental chunks in every
// modern browser). Fallback path: XHR responseText polling, which keeps
// streaming working in older browsers and embedded webviews where fetch
// body streams are buffered until the response completes. The XHR path uses
// dart:html, so this file must only be compiled for dart2js web builds.
import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Parses SSE lines from a streaming HTTP response.
///
/// Same event shape as the native streamer: JSON `data:` lines carrying
/// `content`, `reasoning`, `tool_status`, or `error` fields, terminated by
/// a bare `data: [DONE]`.
Future<String> streamSseResponse({
  required String url,
  required Map<String, String> headers,
  required String body,
  required void Function(String chunk) onChunk,
  void Function(String chunk)? onReasoning,
  void Function(String toolStatus)? onToolStatus,
  void Function(String error)? onError,
  Duration timeout = const Duration(seconds: 120),
}) async {
  final fullResponse = StringBuffer();
  final completer = Completer<String>();
  var lineBuffer = '';
  // SSE data payloads waiting to be rendered. Network chunks can contain
  // dozens of events at once (especially after a thinking phase), so we
  // drain them frame-by-frame at a visible pace instead of letting a burst
  // paint the whole reply in a single frame.
  final pending = <String>[];
  var drainScheduled = false;
  var streamDone = false;

  void completeRequest() {
    if (!completer.isCompleted) {
      completer.complete(fullResponse.toString());
    }
  }

  void drain() {
    if (pending.isEmpty) return;
    var budget = 4;
    while (pending.isNotEmpty && budget > 0) {
      budget--;
      final data = pending.removeAt(0);
      _processSseData(
        data,
        fullResponse,
        onChunk,
        onReasoning: onReasoning,
        onToolStatus: onToolStatus,
        onError: onError,
      );
    }
    if (pending.isEmpty && streamDone) {
      completeRequest();
    }
  }

  void startDrain() {
    if (drainScheduled) return;
    drainScheduled = true;
    // Drive pacing with requestAnimationFrame: browser timers get throttled
    // hard while the app's animations run, which made reply bursts appear
    // all at once. Frame callbacks run on the same clock as the app's own
    // animations, so the queue drains at a steady visible pace.
    html.window.requestAnimationFrame((_) {
      drainScheduled = false;
      drain();
      if (pending.isNotEmpty) startDrain();
    });
  }

  void processText(String text) {
    lineBuffer += text;
    final lines = lineBuffer.split('\n');
    lineBuffer = lines.removeLast();
    for (final line in lines) {
      final trimmed = line.trimRight();
      if (!trimmed.startsWith('data: ')) continue;
      pending.add(trimmed.substring(6).trim());
    }
    startDrain();
  }

  void finish() {
    streamDone = true;
    if (lineBuffer.isNotEmpty) {
      final trimmed = lineBuffer.trimRight();
      if (trimmed.startsWith('data: ')) {
        pending.add(trimmed.substring(6).trim());
      }
    }
    lineBuffer = '';
    if (pending.isEmpty) {
      completeRequest();
    } else {
      startDrain();
    }
  }

  Timer? timeoutTimer;
  void armTimeout(web.AbortController? ac, web.XMLHttpRequest? xhr) {
    timeoutTimer = Timer(timeout, () {
      ac?.abort();
      xhr?.abort();
      if (!completer.isCompleted) {
        completer.completeError(TimeoutException('AI request timed out', timeout));
      }
    });
  }

  Future<String> responseFuture = completer.future;
  try {
    final ac = web.AbortController();
    final requestHeaders = web.Headers();
    headers.forEach((key, value) => requestHeaders.append(key, value));

    final response = await web.window
        .fetch(
          url.toJS,
          web.RequestInit(
            method: 'POST',
            headers: requestHeaders,
            body: body.toJS,
            signal: ac.signal,
          ),
        )
        .toDart
        .timeout(timeout);
    armTimeout(ac, null);

    if (!response.ok) {
      final errText = (await response.text().toDart).toDart;
      String errorMsg;
      try {
        final errorData = jsonDecode(errText) as Map<String, dynamic>;
        errorMsg = errorData['error'] as String? ?? 'Unknown error';
      } catch (_) {
        errorMsg = 'AI service returned ${response.status}';
      }
      throw Exception(errorMsg);
    }

    final stream = response.body;
    if (stream == null) {
      // fetch body streaming unavailable: fall back to XHR polling.
      _streamViaXhr(
        url,
        headers,
        body,
        timeout,
        processText,
        finish,
        completer,
      );
      responseFuture = completer.future;
    } else {
      final reader = stream.getReader() as web.ReadableStreamDefaultReader;
      // The reply accumulator is written only by [_processSseData]; decoded
      // chunk text goes through a separate buffer so it can be cleared without
      // ever touching the accumulated reply.
      final decodedBuffer = StringBuffer();
      final decoderSink = const Utf8Decoder(allowMalformed: true)
          .startChunkedConversion(_StringBufferSink(decodedBuffer));
      try {
        while (true) {
          final chunk = await reader.read().toDart;
          // The final chunk can carry `done: true` together with a value, so
          // process the value before checking the completion flag.
          final value = chunk.value;
          if (value != null) {
            final bytes = (value as JSUint8Array).toDart;
            decoderSink.add(bytes);
            final text = decodedBuffer.toString();
            decodedBuffer.clear();
            processText(text);
          }
          if (chunk.done) break;
        }
        decoderSink.close();
      } finally {
        reader.releaseLock();
      }
      finish();
      timeoutTimer?.cancel();
      responseFuture = completer.future;
    }
  } catch (e) {
    timeoutTimer?.cancel();
    if (!completer.isCompleted) {
      completer.completeError(e);
    }
  }
  return responseFuture;
}

/// XHR polling fallback: reads `responseText` on a timer so chunks surface
/// incrementally even where `ReadableStream` is unavailable or buffered.
void _streamViaXhr(
  String url,
  Map<String, String> headers,
  String body,
  Duration timeout,
  void Function(String text) processText,
  void Function() finish,
  Completer<String> completer,
) {
  final xhr = html.HttpRequest();
  xhr.open('POST', url);
  headers.forEach((key, value) => xhr.setRequestHeader(key, value));

  var previousText = '';
  var finished = false;
  final poll = Timer.periodic(const Duration(milliseconds: 40), (timer) {
    if (finished) {
      timer.cancel();
      return;
    }
    final currentText = xhr.responseText ?? '';
    if (currentText.length > previousText.length) {
      processText(currentText.substring(previousText.length));
      previousText = currentText;
    }
    if (xhr.readyState != 4) return;
    finished = true;
    timer.cancel();
    if (xhr.status == 200) {
      finish();
      return;
    }
    String errorMsg;
    try {
      final errorData =
          jsonDecode(xhr.responseText ?? '{}') as Map<String, dynamic>;
      errorMsg = errorData['error'] as String? ?? 'Unknown error';
    } catch (_) {
      errorMsg = 'AI service returned ${xhr.status}';
    }
    if (!completer.isCompleted) {
      completer.completeError(Exception(errorMsg));
    }
  });

  try {
    xhr.send(body);
  } catch (e) {
    poll.cancel();
    finished = true;
    if (!completer.isCompleted) {
      completer.completeError(e);
    }
  }
}

/// Sink used to decode UTF-8 across chunk boundaries (emoji-safe).
class _StringBufferSink implements ChunkedConversionSink<String> {
  final StringBuffer buffer;

  _StringBufferSink(this.buffer);

  @override
  void add(String chunk) => buffer.write(chunk);

  @override
  void close() {}
}

/// Process a single SSE `data:` payload (already stripped of the `data: `
/// prefix and trailing newline).
void _processSseData(
  String data,
  StringBuffer fullResponse,
  void Function(String chunk) onChunk, {
  void Function(String chunk)? onReasoning,
  void Function(String toolStatus)? onToolStatus,
  void Function(String error)? onError,
}) {
  if (data == '[DONE]') return;
  try {
    final parsed = jsonDecode(data) as Map<String, dynamic>;
    final reasoning = parsed['reasoning'] as String? ?? '';
    if (reasoning.isNotEmpty && onReasoning != null) {
      onReasoning(reasoning);
    }
    final content = parsed['content'] as String? ?? '';
    if (content.isNotEmpty) {
      fullResponse.write(content);
      onChunk(content);
    }
    final toolStatus = parsed['tool_status'] as String? ?? '';
    if (toolStatus.isNotEmpty && onToolStatus != null) {
      onToolStatus(toolStatus);
    }
    final error = parsed['error'] as String? ?? '';
    if (error.isNotEmpty && onError != null) {
      onError(error);
    }
  } catch (_) {
    // Skip malformed JSON chunks.
  }
}
