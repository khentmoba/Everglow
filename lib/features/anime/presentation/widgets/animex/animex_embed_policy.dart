class AnimeXEmbedPolicy {
  const AnimeXEmbedPolicy._();

  static const _unsandboxedHosts = {
    'megaplay.buzz',
    'megaplays.se',
    'megaplay.su',
    'anixo.buzz',
    'tryembed.us.cc',
  };

  static const _originReferrerHosts = {
    'megaplay.buzz',
    'megaplays.se',
    'megaplay.su',
    'anixo.buzz',
    'megavid.buzz',
    'tryembed.us.cc',
  };

  static bool _matches(String host, String apex) =>
      host == apex || host.endsWith('.$apex');

  static String _hostOf(String url) =>
      Uri.tryParse(url)?.host.toLowerCase() ?? '';

  static bool sandboxAllowed(String url) {
    final host = _hostOf(url);
    return !_unsandboxedHosts.any((apex) => _matches(host, apex));
  }

  static String referrerFor(String url, String fallback) {
    final host = _hostOf(url);
    if (_originReferrerHosts.any((apex) => _matches(host, apex))) {
      return 'strict-origin-when-cross-origin';
    }
    return fallback;
  }
}
