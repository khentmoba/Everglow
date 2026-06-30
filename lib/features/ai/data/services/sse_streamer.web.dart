// @dart = 3.11
// Web-platform implementation: uses dart:html HttpRequest with incremental
// progress events for real SSE streaming in the browser.
import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;

/// Parses SSE lines from a streaming HTTP response.
///
/// Web implementation: uses [html.HttpRequest] with [onProgress] events,
/// which fire incrementally as data arrives from the server. This is
/// necessary because [http.Client.send] on web buffers the entire response
/// before yielding, which defeats SSE streaming.
Future<String> streamSseResponse({
  required String url,
  required Map<String, String> headers,
  required String body,
  required void Function(String chunk) onChunk,
  Duration timeout = const Duration(seconds: 65),
}) async {
  final fullResponse = StringBuffer();
  final completer = Completer<String>();

  final request = html.HttpRequest();
  request.open('POST', url);
  headers.forEach((k, v) => request.setRequestHeader(k, v));
  request.responseType = 'text';

  // Tracks how much of responseText we've already processed
  var processedUpTo = 0;

  request.onProgress.listen((_) {
    final text = request.responseText;
    if (text == null || text.length <= processedUpTo) return;

    // Process only the newly received portion
    final newText = text.substring(processedUpTo);
    processedUpTo = text.length;

    // Split into lines to parse SSE events
    final lines = const LineSplitter().convert(newText);
    for (final line in lines) {
      if (line.startsWith('data: ')) {
        final data = line.substring(6).trim();
        if (data == '[DONE]') continue;
        try {
          final parsed = jsonDecode(data) as Map<String, dynamic>;
          final content = parsed['content'] as String? ?? '';
          if (content.isNotEmpty) {
            fullResponse.write(content);
            onChunk(content);
          }
        } catch (_) {
          // skip malformed JSON chunks
        }
      }
    }
  });

  request.onLoadEnd.listen((_) {
    if (!completer.isCompleted) {
      completer.complete(fullResponse.toString());
    }
  });

  request.onError.listen((_) {
    if (!completer.isCompleted) {
      completer.completeError(
        Exception('Network error during AI streaming'),
      );
    }
  });

  // Timeout
  final timer = Timer(timeout, () {
    if (!completer.isCompleted) {
      request.abort();
      completer.completeError(
        TimeoutException('AI streaming timed out', timeout),
      );
    }
  });

  request.send(body);

  try {
    return await completer.future;
  } finally {
    timer.cancel();
  }
}
