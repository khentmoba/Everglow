import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;
import 'sse_cancellation.dart';

Future<String> streamSseResponse({
  required String url,
  required Map<String, String> headers,
  required String body,
  required void Function(String chunk) onChunk,
  void Function(String chunk)? onReasoning,
  void Function(String toolStatus)? onToolStatus,
  void Function(Map<String, dynamic> result)? onToolResult,
  void Function(String error)? onError,
  Duration timeout = const Duration(seconds: 120),
  SseCancellation? cancellation,
}) async {
  final fullResponse = StringBuffer();
  final completer = Completer<String>();
  var lineBuffer = '';
  final pending = <String>[];
  var drainScheduled = false;
  var streamDone = false;
  var paintedFirstToken = false;

  bool payloadHasText(String data, String key) {
    final i = data.indexOf('"$key":"');
    if (i < 0) return false;
    final v = i + key.length + 4;
    if (v >= data.length) return false;
    return data[v] != '"';
  }

  bool pendingHasVisibleToken() {
    for (final d in pending) {
      if (payloadHasText(d, 'content') || payloadHasText(d, 'reasoning')) {
        return true;
      }
    }
    return false;
  }

  web.EventListener? visibilityListener;

  void detachVisibilityListener() {
    final listener = visibilityListener;
    if (listener == null) return;
    visibilityListener = null;
    web.document.removeEventListener('visibilitychange', listener);
  }

  void completeRequest() {
    detachVisibilityListener();
    if (!completer.isCompleted) {
      completer.complete(fullResponse.toString());
    }
  }

  void drainAll() {
    while (pending.isNotEmpty) {
      final data = pending.removeAt(0);
      _processSseData(
        data,
        fullResponse,
        onChunk,
        onReasoning: onReasoning,
        onToolStatus: onToolStatus,
        onToolResult: onToolResult,
        onError: onError,
      );
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
        onToolResult: onToolResult,
        onError: onError,
      );
    }
    if (pending.isEmpty && streamDone) {
      completeRequest();
    }
  }

  void startDrain() {
    if (web.document.hidden) {
      drainScheduled = false;
      drainAll();
      if (streamDone) completeRequest();
      return;
    }
    if (drainScheduled) return;
    if (!paintedFirstToken && pendingHasVisibleToken()) {
      drain();
      paintedFirstToken = !pendingHasVisibleToken();
      if (pending.isNotEmpty) startDrain();
      return;
    }
    drainScheduled = true;
    web.window.requestAnimationFrame(
      ((num _) {
        drainScheduled = false;
        drain();
        if (pending.isNotEmpty) startDrain();
      }).toJS,
    );
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
    if (pending.isEmpty || web.document.hidden) {
      drainAll();
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
        completer.completeError(
          TimeoutException('AI request timed out', timeout),
        );
      }
    });
  }

  Future<String> responseFuture = completer.future;
  visibilityListener = ((web.Event _) {
    if (!web.document.hidden && pending.isNotEmpty) {
      startDrain();
    }
  }).toJS;
  web.document.addEventListener('visibilitychange', visibilityListener);
  try {
    final ac = web.AbortController();
    cancellation?.attach(() {
      ac.abort();
      pending.clear();
      if (!completer.isCompleted) {
        completer.completeError(StateError('Reply stopped'));
      }
    });
    armTimeout(ac, null);
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
      _streamViaXhr(
        url,
        headers,
        body,
        timeout,
        processText,
        finish,
        completer,
        cancellation,
      );
      responseFuture = completer.future;
    } else {
      final reader = stream.getReader() as web.ReadableStreamDefaultReader;
      final decodedBuffer = StringBuffer();
      final decoderSink = const Utf8Decoder(
        allowMalformed: true,
      ).startChunkedConversion(_StringBufferSink(decodedBuffer));
      try {
        while (true) {
          final chunk = await reader.read().toDart;
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
    detachVisibilityListener();
    timeoutTimer?.cancel();
    if (!completer.isCompleted) {
      completer.completeError(e);
    }
  }
  try {
    return await responseFuture;
  } finally {
    timeoutTimer?.cancel();
    detachVisibilityListener();
    cancellation?.attach(null);
  }
}

void _streamViaXhr(
  String url,
  Map<String, String> headers,
  String body,
  Duration timeout,
  void Function(String text) processText,
  void Function() finish,
  Completer<String> completer,
  SseCancellation? cancellation,
) {
  final xhr = web.XMLHttpRequest();
  xhr.open('POST', url);
  headers.forEach((key, value) => xhr.setRequestHeader(key, value));

  var previousText = '';
  var finished = false;
  final poll = Timer.periodic(const Duration(milliseconds: 40), (timer) {
    if (finished) {
      timer.cancel();
      return;
    }
    final currentText = xhr.responseText;
    if (currentText.length > previousText.length) {
      processText(currentText.substring(previousText.length));
      previousText = currentText;
    }
    if (xhr.readyState != web.XMLHttpRequest.DONE) return;
    finished = true;
    timer.cancel();
    if (xhr.status == 200) {
      finish();
      return;
    }
    String errorMsg;
    try {
      final errorData = jsonDecode(xhr.responseText) as Map<String, dynamic>;
      errorMsg = errorData['error'] as String? ?? 'Unknown error';
    } catch (_) {
      errorMsg = 'AI service returned ${xhr.status}';
    }
    if (!completer.isCompleted) {
      completer.completeError(Exception(errorMsg));
    }
  });

  cancellation?.attach(() {
    finished = true;
    poll.cancel();
    xhr.abort();
    if (!completer.isCompleted) {
      completer.completeError(StateError('Reply stopped'));
    }
  });

  try {
    xhr.send(body.toJS);
  } catch (e) {
    poll.cancel();
    finished = true;
    if (!completer.isCompleted) {
      completer.completeError(e);
    }
  }
}

class _StringBufferSink implements ChunkedConversionSink<String> {
  final StringBuffer buffer;

  _StringBufferSink(this.buffer);

  @override
  void add(String chunk) => buffer.write(chunk);

  @override
  void close() {}
}

void _processSseData(
  String data,
  StringBuffer fullResponse,
  void Function(String chunk) onChunk, {
  void Function(String chunk)? onReasoning,
  void Function(String toolStatus)? onToolStatus,
  void Function(Map<String, dynamic> result)? onToolResult,
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
    final toolResult = parsed['tool_result'];
    if (toolResult is Map<String, dynamic> && onToolResult != null) {
      onToolResult(toolResult);
    } else if (toolResult is Map && onToolResult != null) {
      onToolResult(Map<String, dynamic>.from(toolResult));
    }
    final error = parsed['error'] as String? ?? '';
    if (error.isNotEmpty && onError != null) {
      onError(error);
    }
  } catch (_) {
    // Skip malformed JSON chunks.
  }
}
