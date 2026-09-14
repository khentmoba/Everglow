/// Per-host iframe policy for the AnimeX player frame.
///
/// The third-party anime servers each enforce their own embedding rules
/// (verified Sep 2026 against the providers themselves and a working
/// reference site), so one blanket policy can't cover them:
///
/// - MegaPlay renders "Sandboxed our player is not allowed. Remove
///   sandbox to use it" inside any sandboxed iframe, and answers 410
///   ("We're Sorry") when the load carries no Referer.
/// - Megavid plays through our own ad-free resolver (see
///   AnimeXWatchPage.proxyAnimeBase), so it stays sandboxed with no
///   referrer like our own pages.
///
/// AniXo is no longer offered (a bot-gated relay over MegaPlay), but
/// its entries below stay as a guard in case one of its URLs ever
/// reaches the frame again — as do Megavid's direct-embed entries.
///
/// Our own pages (Everglow embed, trailers) keep the caller's policy.
class AnimeXEmbedPolicy {
  const AnimeXEmbedPolicy._();

  /// Hosts that refuse to play inside a sandboxed iframe at all.
  static const _unsandboxedHosts = {'megaplay.buzz', 'anixo.buzz'};

  /// Hosts that reject referrer-less loads and need the origin sent.
  static const _originReferrerHosts = {
    'megaplay.buzz',
    'anixo.buzz',
    'megavid.buzz',
  };

  static bool _matches(String host, String apex) =>
      host == apex || host.endsWith('.$apex');

  static String _hostOf(String url) =>
      Uri.tryParse(url)?.host.toLowerCase() ?? '';

  /// Whether [url] may play inside the sandboxed player frame.
  /// MegaPlay and AniXo detect the sandbox and block playback, so the
  /// frame skips the `sandbox` attribute for them (matching the working
  /// reference site); every other embed stays caged.
  static bool sandboxAllowed(String url) {
    final host = _hostOf(url);
    return !_unsandboxedHosts.any((apex) => _matches(host, apex));
  }

  /// Referrer policy [url] needs. The third-party servers all block
  /// referrer-less loads, so they get the origin; anything else keeps
  /// the caller's [fallback] (our own pages stay `no-referrer`).
  static String referrerFor(String url, String fallback) {
    final host = _hostOf(url);
    if (_originReferrerHosts.any((apex) => _matches(host, apex))) {
      return 'strict-origin-when-cross-origin';
    }
    return fallback;
  }
}
