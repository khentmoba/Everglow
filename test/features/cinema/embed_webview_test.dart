import 'package:flutter_test/flutter_test.dart';
import 'package:everglow/features/cinema/presentation/widgets/embed_webview.dart';

void main() {
  test('owned failure messages reject other URLs and malformed traffic', () {
    expect(
      EmbedWebView.isOwnedPlayerUrl(
        'https://everglow-1c6db.web.app/embed.html?tmdbId=1',
      ),
      isTrue,
    );
    for (final url in [
      'http://everglow-1c6db.web.app/embed.html',
      'https://evil.test/embed.html',
      'https://everglow-1c6db.web.app/other',
    ]) {
      expect(EmbedWebView.isOwnedPlayerUrl(url), isFalse);
    }
    expect(
      EmbedWebView.isPlayerFailure('{"type":"everglow-embed-failed"}'),
      isTrue,
    );
    expect(
      EmbedWebView.isPlayerFailure('{"type":"cinesrc:nextepisode"}'),
      isFalse,
    );
    expect(EmbedWebView.isPlayerFailure('invalid json'), isFalse);
  });

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
