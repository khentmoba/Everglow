import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Parses SSE lines from a streaming HTTP response.
///
/// Native implementation: uses [http.Client.send] with [StreamedResponse.stream],
/// which yields data incrementally on mobile/desktop platforms.
Future<String> streamSseResponse({
  required String url,
  required Map<String, String> headers,
  required String body,
  required void Function(String chunk) onChunk,
  void Function(String chunk)? onReasoning,
  void Function(String toolStatus)? onToolStatus,
  Duration timeout = const Duration(seconds: 120),
}) async {
  final fullResponse = StringBuffer();

  final request = http.Request('POST', Uri.parse(url))
    ..headers.addAll(headers)
    ..body = body;

  final client = http.Client();
  try {
    final response =
        await client.send(request).timeout(timeout);

    if (response.statusCode == 200) {
      await for (final line
          in response.stream
              .transform(utf8.decoder)
              .transform(const LineSplitter())) {
        if (line.startsWith('data: ')) {
          final data = line.substring(6).trim();
          if (data == '[DONE]') break;
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
          } catch (_) {
            // skip malformed JSON chunks
          }
        }
      }
      return fullResponse.toString();
    }

    // Handle error responses
    String errorMsg;
    try {
      final errorBody = await response.stream.bytesToString();
      final errorData = jsonDecode(errorBody);
      errorMsg = errorData['error'] ?? 'Unknown error';
    } catch (_) {
      errorMsg = 'AI service returned ${response.statusCode}';
    }
    throw Exception(errorMsg);
  } finally {
    client.close();
  }
}
