import 'package:everglow/features/ai/data/services/ai_service.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> msg(int i) => {
      'role': i.isEven ? 'user' : 'assistant',
      'content': 'message $i',
    };

void main() {
  group('trimHistoryForRequest', () {
    test('short history passes through untouched', () {
      final payloads = List.generate(10, msg);
      final trimmed = AIService.trimHistoryForRequest(payloads);
      expect(trimmed.length, 10);
      expect(trimmed.first['content'], 'message 0');
      expect(trimmed.last['content'], 'message 9');
    });

    test('exactly at the limit passes through untouched', () {
      final payloads = List.generate(AIService.historyLimit, msg);
      expect(
        AIService.trimHistoryForRequest(payloads).length,
        AIService.historyLimit,
      );
    });

    test('long history keeps only the trailing 20 in order', () {
      final payloads = List.generate(50, msg);
      final trimmed = AIService.trimHistoryForRequest(payloads);
      expect(trimmed.length, 20);
      expect(trimmed.first['content'], 'message 30');
      expect(trimmed.last['content'], 'message 49');
    });

    test('guardian limit keeps only the trailing 12', () {
      final payloads = List.generate(30, msg);
      final trimmed = AIService.trimHistoryForRequest(
        payloads,
        limit: AIService.guardianHistoryLimit,
      );
      expect(trimmed.length, 12);
      expect(trimmed.first['content'], 'message 18');
      expect(trimmed.last['content'], 'message 29');
    });
  });
}
