import 'package:everglow/features/anime/presentation/widgets/animex/animex_embed_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AnimeXEmbedPolicy', () {
    test('sandboxAllowed refuses MegaPlay, AniXo, and TryEmbed only', () {
      // MegaPlay, AniXo, and TryEmbed detect the sandbox attribute and
      // block playback.
      expect(
        AnimeXEmbedPolicy.sandboxAllowed(
          'https://megaplay.buzz/stream/ani/21/1/sub',
        ),
        isFalse,
      );
      expect(
        AnimeXEmbedPolicy.sandboxAllowed(
          'https://anixo.buzz/embed/ani/21/1?track=sub',
        ),
        isFalse,
      );
      expect(
        AnimeXEmbedPolicy.sandboxAllowed(
          'https://tryembed.us.cc/embed/anime/21/1/sub',
        ),
        isFalse,
      );
      // Megavid, VidCore, Rive, Fmov have no detector — they stay caged.
      expect(
        AnimeXEmbedPolicy.sandboxAllowed(
          'https://megavid.buzz/ani/21/1/sub',
        ),
        isTrue,
      );
      expect(
        AnimeXEmbedPolicy.sandboxAllowed(
          'https://vidcore.org/embed/tv/1/1/1',
        ),
        isTrue,
      );
      expect(
        AnimeXEmbedPolicy.sandboxAllowed(
          'https://rivestream.us/embed?type=tv&id=1&season=1&episode=1',
        ),
        isTrue,
      );
      expect(
        AnimeXEmbedPolicy.sandboxAllowed(
          'https://fmov.my/embed/anime/1/1/1',
        ),
        isTrue,
      );
      // Our own pages and anything unknown stay sandboxed too.
      expect(
        AnimeXEmbedPolicy.sandboxAllowed(
          'https://everglow-1c6db.web.app/embed.html?tmdbId=1&type=movie',
        ),
        isTrue,
      );
      expect(AnimeXEmbedPolicy.sandboxAllowed('not a url'), isTrue);
    });

    test('referrerFor sends the origin to the third-party servers', () {
      const fallback = 'no-referrer';
      // All three reject referrer-less loads (410 / 403 / Embed Only).
      expect(
        AnimeXEmbedPolicy.referrerFor(
          'https://megaplay.buzz/stream/ani/21/1/sub',
          fallback,
        ),
        'strict-origin-when-cross-origin',
      );
      expect(
        AnimeXEmbedPolicy.referrerFor(
          'https://anixo.buzz/embed/ani/21/1?track=sub',
          fallback,
        ),
        'strict-origin-when-cross-origin',
      );
      expect(
        AnimeXEmbedPolicy.referrerFor(
          'https://megavid.buzz/ani/21/1/sub',
          fallback,
        ),
        'strict-origin-when-cross-origin',
      );
      expect(
        AnimeXEmbedPolicy.referrerFor(
          'https://tryembed.us.cc/embed/anime/21/1/sub',
          fallback,
        ),
        'strict-origin-when-cross-origin',
      );
      // Our own pages keep the caller policy (still no-referrer).
      expect(
        AnimeXEmbedPolicy.referrerFor(
          'https://everglow-1c6db.web.app/embed.html?tmdbId=1&type=movie',
          fallback,
        ),
        fallback,
      );
      expect(
        AnimeXEmbedPolicy.referrerFor(
          'https://www.youtube.com/embed/abc?autoplay=1',
          'strict-origin-when-cross-origin',
        ),
        'strict-origin-when-cross-origin',
      );
    });
  });
}
