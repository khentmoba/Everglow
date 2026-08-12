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

  void processText(String text) {
    lineBuffer += text;
    final lines = lineBuffer.split('\n');
    lineBuffer = lines.removeLast();
    for (final line in lines) {
      _processSseLine(
        line,
        fullResponse,
        onChunk,
        onReasoning: onReasoning,
        onToolStatus: onToolStatus,
        onError: onError,
      );
    }
  }

  void finish() {
    if (lineBuffer.isEmpty) return;
    final lines = lineBuffer.split('\n');
    lineBuffer = '';
    for (final line in lines) {
      _processSseLine(
        line,
        fullResponse,
        onChunk,
        onReasoning: onReasoning,
        onToolStatus: onToolStatus,
        onError: onError,
      );
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
        fullResponse,
        completer,
      );
      return completer.future;
    }

    final reader = stream.getReader() as web.ReadableStreamDefaultReader;
    // The reply accumulator is written only by [_processSseLine]; decoded
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
    if (!completer.isCompleted) {
      completer.complete(fullResponse.toString());
    }
    return completer.future;
  } catch (e) {
    timeoutTimer?.cancel();
    if (!completer.isCompleted) {
      completer.completeError(e);
    }
    return completer.future;
  }
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
  StringBuffer fullResponse,
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
    finish();
    if (xhr.status == 200) {
      if (!completer.isCompleted) {
        completer.complete(fullResponse.toString());
      }
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

/// Process a single complete SSE line (split on `\n`, without the trailing
/// newline). Throws on `error` events so callers surface them like errors.
void _processSseLine(
  String line,
  StringBuffer fullResponse,
  void Function(String chunk) onChunk, {
  void Function(String chunk)? onReasoning,
  void Function(String toolStatus)? onToolStatus,
  void Function(String error)? onError,
}) {
  final trimmed = line.trimRight();
  if (trimmed.isEmpty) return;
  if (!trimmed.startsWith('data: ')) return;
  final data = trimmed.substring(6).trim();
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
