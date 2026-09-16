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

  Map<String, dynamic> photoMsg(int i) => {
        'role': 'user',
        'content': [
          {'type': 'text', 'text': 'look $i'},
          {'type': 'image_url', 'image_url': {'url': 'https://img/$i'}},
        ],
      };

  bool hasImage(Map<String, dynamic> p) {
    final content = p['content'];
    return content is List &&
        content.any((b) => b is Map && b['type'] == 'image_url');
  }

  group('stripStaleImages', () {
    test('text-only history passes through untouched', () {
      final payloads = List.generate(10, msg);
      final stripped = AIService.stripStaleImages(payloads);
      expect(stripped.length, 10);
      expect(stripped.any(hasImage), isFalse);
    });

    test('keeps images in the last two photo turns only', () {
      final payloads = [
        photoMsg(0),
        msg(1),
        photoMsg(2),
        msg(3),
        photoMsg(4),
      ];
      final stripped = AIService.stripStaleImages(payloads);
      expect(stripped.length, 5);
      expect(hasImage(stripped[0]), isFalse);
      expect(stripped[0]['content'], 'look 0');
      expect(hasImage(stripped[2]), isTrue);
      expect(hasImage(stripped[4]), isTrue);
      // Order and roles preserved.
      expect(stripped[1]['content'], 'message 1');
      expect(stripped[0]['role'], 'user');
    });

    test('two or fewer photo turns keep everything', () {
      final payloads = [photoMsg(0), msg(1), photoMsg(2)];
      final stripped = AIService.stripStaleImages(payloads);
      expect(hasImage(stripped[0]), isTrue);
      expect(hasImage(stripped[2]), isTrue);
    });
  });
}
