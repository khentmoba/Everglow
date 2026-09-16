import 'package:flutter_test/flutter_test.dart';
import 'package:everglow/features/cinema/presentation/widgets/embed_webview.dart';

void main() {
  group('EmbedWebView.parsePlayerEpisode', () {
    test('parses bridged cinesrc episode events', () {
      expect(
        EmbedWebView.parsePlayerEpisode(
          '{"type":"cinesrc:nextepisode","season":2,"episode":3}',
        ),
        (2, 3),
      );
    });

    test('returns null for foreign bridge traffic', () {
      // Other message types.
      expect(
        EmbedWebView.parsePlayerEpisode('{"type":"cinesrc:ready"}'),
        isNull,
      );
      // Missing numbers.
      expect(
        EmbedWebView.parsePlayerEpisode('{"type":"cinesrc:nextepisode"}'),
        isNull,
      );
      expect(
        EmbedWebView.parsePlayerEpisode(
          '{"type":"cinesrc:nextepisode","season":"x","episode":1}',
        ),
        isNull,
      );
      // Malformed JSON and non-objects.
      expect(EmbedWebView.parsePlayerEpisode('not json'), isNull);
      expect(EmbedWebView.parsePlayerEpisode(''), isNull);
      expect(EmbedWebView.parsePlayerEpisode('[1,2]'), isNull);
      expect(EmbedWebView.parsePlayerEpisode('"cinesrc:nextepisode"'), isNull);
    });
  });
}
