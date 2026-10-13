import 'dart:async';
import 'dart:io';

import 'package:everglow/features/ai/data/services/sse_cancellation.dart';
import 'package:everglow/features/ai/data/services/sse_streamer_native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cancelling an active SSE request closes its transport', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final firstToken = Completer<void>();
    final cancellation = SseCancellation();
    server.listen((request) async {
      await request.drain<void>();
      request.response.bufferOutput = false;
      request.response.headers.contentType = ContentType(
        'text',
        'event-stream',
      );
      request.response.write('data: {"content":"Demo reply"}\n\n');
      await request.response.flush();
    });
    final response = streamSseResponse(
      url: 'http://127.0.0.1:${server.port}',
      headers: {},
      body: '{}',
      cancellation: cancellation,
      onChunk: (_) {
        if (!firstToken.isCompleted) firstToken.complete();
      },
    );
    final completion = expectLater(response, throwsA(anything));
    await firstToken.future.timeout(const Duration(seconds: 3));
    cancellation.cancel();
    await completion.timeout(const Duration(seconds: 3));
  });

  test(
    'a cancellation requested before transport attachment still aborts it',
    () {
      final cancellation = SseCancellation()..cancel();
      var aborted = false;
      cancellation.attach(() => aborted = true);
      expect(aborted, isTrue);
    },
  );
}
