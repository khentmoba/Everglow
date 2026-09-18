import 'package:everglow/features/ai/data/services/ai_service.dart';
import 'package:everglow/features/ai/domain/models/ai_conversation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('webSourcesFromToolResults', () {
    test('pulls title, url, and site from web_search results', () {
      final sources = AIService.webSourcesFromToolResults([
        {
          'tool': 'web_search',
          'query': 'ethel cain tour',
          'results': [
            {
              'title': 'Tour dates',
              'url': 'https://example.com/tour',
              'site': 'Example',
            },
            {
              'title': 'Tickets',
              'url': 'https://tickets.example.com/e',
              'site': 'Tickets',
            },
          ],
        },
      ]);
      expect(sources.length, 2);
      expect(sources[0], {
        'title': 'Tour dates',
        'url': 'https://example.com/tour',
        'site': 'Example',
      });
    });

    test('uses the page host as site for read_web_page', () {
      final sources = AIService.webSourcesFromToolResults([
        {
          'tool': 'read_web_page',
          'pages': [
            {'title': 'A page', 'url': 'https://www.example.com/a'},
          ],
        },
      ]);
      expect(sources.length, 1);
      expect(sources[0]['site'], 'example.com');
      expect(sources[0]['url'], 'https://www.example.com/a');
    });

    test('dedups by url across tools and caps at five', () {
      final results = List.generate(
        4,
        (i) => {
          'title': 'R$i',
          'url': 'https://example.com/$i',
          'site': 'Example',
        },
      );
      final sources = AIService.webSourcesFromToolResults([
        {'tool': 'web_search', 'results': results},
        {
          'tool': 'read_web_page',
          'pages': [
            // Duplicate of R0 — dropped.
            {'title': 'R0 again', 'url': 'https://example.com/0'},
            {'title': 'P1', 'url': 'https://example.com/p1'},
            {'title': 'P2', 'url': 'https://example.com/p2'},
          ],
        },
      ]);
      expect(sources.length, 5);
      final urls = sources.map((s) => s['url']).toList();
      expect(urls.toSet().length, 5);
    });

    test('takes completed browses, skips running polls', () {
      final sources = AIService.webSourcesFromToolResults([
        {
          'tool': 'browse_web',
          'status': 'RUNNING',
          'run_id': 'run-1',
          'url': 'https://shop.example.com/beans',
        },
        {
          'tool': 'browse_web',
          'status': 'COMPLETED',
          'run_id': 'run-1',
          'url': 'https://shop.example.com/beans',
          'title': 'Beans',
        },
      ]);
      expect(sources.length, 1);
      expect(sources[0], {
        'title': 'Beans',
        'url': 'https://shop.example.com/beans',
        'site': 'shop.example.com',
      });
    });

    test('skips non-http urls and ignores other tools', () {
      final sources = AIService.webSourcesFromToolResults([
        {
          'tool': 'web_search',
          'results': [
            {'title': 'Bad', 'url': 'not-a-url', 'site': ''},
            {'title': 'Empty', 'url': '', 'site': ''},
          ],
        },
        {'tool': 'set_mood', 'success': true},
      ]);
      expect(sources, isEmpty);
    });
  });

  group('AIMessage sources', () {
    test('round-trips through json and stays out of api payloads', () {
      final msg = AIMessage(
        role: 'assistant',
        content: 'hello',
        sources: [
          {'title': 'T', 'url': 'https://example.com', 'site': 'Example'},
        ],
      );
      final restored = AIMessage.fromJson(msg.toJson());
      expect(restored.sources.length, 1);
      expect(restored.sources[0]['url'], 'https://example.com');
      // Sources never ride to the LLM — text history only.
      expect(msg.toApiPayload(), {'role': 'assistant', 'content': 'hello'});
    });

    test('old messages without sources default to empty', () {
      final restored = AIMessage.fromJson({'role': 'user', 'content': 'hi'});
      expect(restored.sources, isEmpty);
      expect(restored.toJson().containsKey('sources'), isFalse);
    });
  });
}
