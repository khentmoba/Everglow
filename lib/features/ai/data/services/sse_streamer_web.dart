// Web-platform implementation: uses dart:html HttpRequest with onProgress
// to receive SSE chunks incrementally as the server sends them.
import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;

/// Parses SSE lines from a streaming HTTP response.
///
/// Uses [html.HttpRequest] with [onProgress] to receive data as it arrives.
/// This is more reliable than the JS fetch() + ReadableStream approach
/// because dart:html is natively supported by Flutter web and doesn't
/// require manual JS interop.
Future<String> streamSseResponse({
  required String url,
  required Map<String, String> headers,
  required String body,
  required void Function(String chunk) onChunk,
  void Function(String chunk)? onReasoning,
  Duration timeout = const Duration(seconds: 65),
}) async {
  final fullResponse = StringBuffer();
  final completer = Completer<String>();

  try {
    final request = html.HttpRequest();
    request.open('POST', url);
    request.timeout = timeout.inMilliseconds;

    // Set request headers
    headers.forEach((key, value) {
      request.setRequestHeader(key, value);
    });

    String previousText = '';

    request.onProgress.listen((_) {
      // responseText contains whatever text has been received so far.
      final currentText = request.responseText ?? '';
      if (currentText.length > previousText.length) {
        final newData = currentText.substring(previousText.length);
        _processSseChunk(newData, fullResponse, onChunk, onReasoning: onReasoning);
        previousText = currentText;
      }
    });

    request.onLoad.listen((_) {
      // Final check: process any remaining data from last chunk
      final finalText = request.responseText ?? '';
      if (finalText.length > previousText.length) {
        final newData = finalText.substring(previousText.length);
        _processSseChunk(newData, fullResponse, onChunk, onReasoning: onReasoning);
      }

      if (request.status == 200) {
        completer.complete(fullResponse.toString());
      } else {
        String errorMsg;
        try {
          final errorData = jsonDecode(finalText) as Map<String, dynamic>;
          errorMsg = errorData['error'] ?? 'Unknown error';
        } catch (_) {
          errorMsg = 'AI service returned ${request.status}';
        }
        completer.completeError(Exception(errorMsg));
      }
    });

    request.onError.listen((_) {
      completer.completeError(
          Exception('Network error: ${request.statusText}'));
    });

    request.send(body);

    return completer.future;
  } catch (e) {
    completer.completeError(e);
  }

  return completer.future;
}

/// Process a chunk of raw SSE data (may contain partial lines).
void _processSseChunk(
  String chunk,
  StringBuffer fullResponse,
  void Function(String chunk) onChunk, {
  void Function(String chunk)? onReasoning,
}) {
  final lines = chunk.split('\n');
  for (final line in lines) {
    final trimmed = line.trimRight();
    if (trimmed.isEmpty) continue;
    if (!trimmed.startsWith('data: ')) continue;
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
    } catch (_) {
      // Skip malformed JSON chunks
    }
  }
}
