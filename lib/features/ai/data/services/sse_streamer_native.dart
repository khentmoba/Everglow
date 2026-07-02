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
  Duration timeout = const Duration(seconds: 65),
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
