// Web-platform implementation: uses dart:html HttpRequest
// with a polling timer on responseText to receive SSE chunks
// incrementally. XHR onProgress may not fire per-byte in Flutter web.
import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;

/// Parses SSE lines from a streaming HTTP response.
///
/// Uses [html.HttpRequest] with a 30ms polling timer on responseText
/// to detect new data as it arrives, independent of onProgress timing.
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
  String lineBuffer = '';

  try {
    final request = html.HttpRequest();
    request.open('POST', url);
    request.timeout = timeout.inMilliseconds;

    headers.forEach((key, value) {
      request.setRequestHeader(key, value);
    });

    String previousText = '';
    Timer? pollTimer;

    pollTimer = Timer.periodic(const Duration(milliseconds: 30), (timer) {
      final currentText = request.responseText ?? '';
      if (currentText.length > previousText.length) {
        final newData = currentText.substring(previousText.length);
        lineBuffer += newData;
        previousText = currentText;

        // Process complete lines; keep incomplete tail in buffer
        final lines = lineBuffer.split('\n');
        lineBuffer = lines.removeLast();
        for (final line in lines) {
            _processSseLine(line, fullResponse, onChunk, onReasoning: onReasoning, onToolStatus: onToolStatus, onError: onError);
          }
      }
      if (request.readyState == 4) {
        timer.cancel();
        // Flush any remaining incomplete line
        if (lineBuffer.isNotEmpty) {
          final remaining = lineBuffer.split('\n');
          for (final line in remaining) {
            _processSseLine(line, fullResponse, onChunk, onReasoning: onReasoning, onToolStatus: onToolStatus, onError: onError);
          }
        }

        if (request.status == 200) {
          completer.complete(fullResponse.toString());
        } else {
          String errorMsg;
          try {
            final errorData =
                jsonDecode(request.responseText ?? '{}') as Map<String, dynamic>;
            errorMsg = errorData['error'] ?? 'Unknown error';
          } catch (_) {
            errorMsg = 'AI service returned ${request.status}';
          }
          completer.completeError(Exception(errorMsg));
        }
      }
    });

    request.onError.listen((_) {
      pollTimer?.cancel();
      if (!completer.isCompleted) {
        completer.completeError(
            Exception('Network error: ${request.statusText}'));
      }
    });

    request.send(body);

    return completer.future;
  } catch (e) {
    if (!completer.isCompleted) {
      completer.completeError(e);
    }
  }

  return completer.future;
}

/// Process a single complete SSE line (already split on \n, without the
/// trailing newline character).
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
    // Skip malformed JSON chunks
  }
}
