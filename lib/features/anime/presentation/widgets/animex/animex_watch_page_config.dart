part of 'animex_watch_page.dart';

class AnimeServerOption {
  final String name;
  final String Function(int episode, String audio) urlBuilder;
  final bool available;

  const AnimeServerOption({
    required this.name,
    required this.urlBuilder,
    this.available = true,
  });
}

typedef _ServerOption = AnimeServerOption;

/// Anime detail / watch page: hero with info, video player with server
/// tabs + sub/dub toggle, episode grid, share, playlists and
/// recommendations.
class AnimeXWatchPage extends StatefulWidget {
  final AnimeXController controller;

  const AnimeXWatchPage({super.key, required this.controller});

  /// True when a fetched embed page is the provider's "can't play this"
  /// error instead of a player. Static so the regression tests can pin
  /// every known marker.
  ///
  /// ONLY strings proven absent from healthy player pages belong here
  /// (verified Sep 2026 against all three providers): AniXo's healthy
  /// page carries its hidden sandbox overlay ("please remove sandbox
  /// ... sandbox is not allowed") plus an "all stream servers failed"
  /// toast string, and Megavid's healthy page carries hidden "We're
  /// Sorry" / "Embed Only" templates — so none of those phrases can
  /// ever be markers. What remains: MegaPlay's 410 title, AniXo's
  /// firewall cards, our own failure marker, and the retired VidLink
  /// cards. HTTP status (non-200) is checked separately by the probe.
  static bool isProviderErrorPage(String body) {
    final lower = body.toLowerCase();
    return lower.contains('error code: <span>410</span>') ||
        lower.contains('error - megaplay') ||
        lower.contains('no playable stream sources') ||
        // AniXo firewall cards (its 403 block page). The healthy player
        // only ever says "anti-leech protection" (no "engaged"), so
        // the full phrases stay unambiguous.
        lower.contains('leech block engaged') ||
        lower.contains('leech protection engaged') ||
        lower.contains('403 forbidden') ||
        // VidLink 404s dead embeds with a Next.js "not found" shell (its
        // anime player died sitewide in Sep 2026) and prints its own
        // "Couldn't Find This Episode" card once the bundle runs.
        lower.contains('this page could not be found') ||
        lower.contains("coudn't find this episode") ||
        lower.contains("couldn't find this episode") ||
        (lower.contains('410') && lower.contains('copyright violation'));
  }

  /// Normalizes legacy server names ('Server 1', etc.) to provider names.
  static String normalizeServerName(String? name) {
    if (name == null) return '';
    switch (name) {
      case 'Server 1':
        return 'Everglow';
      // Legacy: the VidLink anime server was removed (dead upstream
      // since Sep 2026). Old saved choices still normalize here and
      // fall back to the first available server in [_load].
      case 'Server 2':
        return 'VidLink';
      case 'Server 3':
        return 'Megavid';
      // Prior branch names ('Mega Play', 'Anixo') map to the current
      // spellings so remembered choices survive the rename.
      case 'Mega Play':
        return 'MegaPlay';
      case 'Anixo':
        return 'AniXo';
      default:
        return name;
    }
  }

  /// Picks the MAL id used for ani.zip mappings lookups. The route often
  /// carries only an AniList id (the id slot reads 0), so prefer the MAL
  /// id from the freshly fetched AniList detail and fall back to the
  /// route's id slot.
  @visibleForTesting
  static int resolveMappingsMalId({int? detailMalId, required int routeMalId}) {
    if (detailMalId != null && detailMalId > 0) return detailMalId;
    return routeMalId;
  }

  static final _seasonInTitleRegex = RegExp(
    r'season\s+(\d+)',
    caseSensitive: false,
  );

  /// Season to persist with watch progress for an anime episode.
  ///
  /// Anime seasons are separate catalog entries ("Black Clover Season 2")
  /// but progress used to hardcode season 1, so the dashboard showed S1E1
  /// against a Season 2 title. Prefer the ani.zip TMDB mapping when known,
  /// otherwise the season in the title, otherwise 1. Movies return null so
  /// shelves never gain stale S1E1 fields.
  @visibleForTesting
  static int? resolveProgressSeason({
    required bool isMovie,
    required String title,
    required int episode,
    required Map<int, ({int season, int episode})> episodeSlots,
  }) {
    if (isMovie) return null;
    final slot = episodeSlots[episode];
    if (slot != null && slot.season > 0) return slot.season;
    final match = _seasonInTitleRegex.firstMatch(title);
    if (match != null) {
      final parsed = int.tryParse(match.group(1) ?? '');
      if (parsed != null && parsed > 0) return parsed;
    }
    return 1;
  }

  /// Maps a player-reported TMDB season/episode back to our episode number.
  ///
  /// The Everglow embed (CineSrc) announces internal episode changes with
  /// the TMDB season/episode it moved to. Shows whose MAL entry starts
  /// mid-series resolve through [episodeSlots] (the same table the player
  /// URL is built from); plain 1:1 shows map season 1 straight across.
  /// Anything unmappable (a jump into another catalog entry's season, an
  /// out-of-range number) returns null so we never highlight the wrong row.
  @visibleForTesting
  static int? mapPlayerEpisodeToMal({
    required int tmdbSeason,
    required int tmdbEpisode,
    required Map<int, ({int season, int episode})> episodeSlots,
    required int episodeCount,
  }) {
    if (tmdbSeason <= 0 || tmdbEpisode <= 0 || episodeCount <= 0) return null;
    if (episodeSlots.isNotEmpty) {
      for (final entry in episodeSlots.entries) {
        if (entry.value.season == tmdbSeason &&
            entry.value.episode == tmdbEpisode) {
          final mal = entry.key;
          return (mal >= 1 && mal <= episodeCount) ? mal : null;
        }
      }
      return null;
    }
    if (tmdbSeason != 1) return null;
    if (tmdbEpisode < 1 || tmdbEpisode > episodeCount) return null;
    return tmdbEpisode;
  }

  /// Base URL of our ad-free anime resolver (see functions/anime.js).
  /// Megavid plays through it instead of the provider's website embed:
  /// the function resolves the episode server-side and serves our own
  /// player page, so no third-party ad or tracker script ever reaches
  /// Clair's phone — and a missing episode answers with the failover
  /// marker (HTTP 502) instead of spinning its loader forever.
  static const String proxyAnimeBase =
      'https://us-central1-everglow-1c6db.cloudfunctions.net/proxyAnime';

  /// Builds the Megavid player URL via our ad-free resolver.
  @visibleForTesting
  static String megavidProxyUrl({
    required int anilistId,
    required int malId,
    required int episode,
    required String audio,
  }) {
    return '$proxyAnimeBase?source=megavid'
        '&anilistId=$anilistId&malId=$malId&ep=$episode&audio=$audio';
  }

  /// Picks the server a visit should open on: the remembered choice
  /// when it is still offered, otherwise Everglow whenever it is
  /// available, otherwise the first available server. Everglow is ours
  /// (no ads, no popups), so it stays the default even when a previous
  /// visit left the index pointing at a third-party server.
  @visibleForTesting
  static int defaultServerIndex(
    List<AnimeServerOption> servers, {
    String? rememberedServer,
  }) {
    final remembered = normalizeServerName(rememberedServer);
    if (remembered.isNotEmpty) {
      final at = servers.indexWhere((s) => s.available && s.name == remembered);
      if (at != -1) return at;
    }
    final everglow = servers.indexWhere(
      (s) => s.available && s.name == 'Everglow',
    );
    if (everglow != -1) return everglow;
    final first = servers.indexWhere((s) => s.available);
    return first == -1 ? 0 : first;
  }

  /// Builds the anime embed servers, cleanest first. Each provider has
  /// its own embedding rules (verified Sep 2026 against the providers
  /// themselves and a working reference site) — the player frame
  /// applies them per host:
  ///
  /// - Everglow: our own embed.html shell around CineSrc. Default for
  ///   fresh titles. TMDB-keyed, so it only becomes available once
  ///   ani.zip supplies a `themoviedb_id`. Sandboxed, no referrer,
  ///   100% ad-free.
  /// - Megavid: our ad-free resolver ([proxyAnimeBase]) keyed on the
  ///   AniList id (falls back to MAL). Sandboxed, no referrer. A dead
  ///   episode answers with the failover marker so the probe advances
  ///   to the next server instead of spinning.
  /// - MegaPlay: third-party embed keyed on the AniList id (falls back
  ///   to MAL). Last resort for titles without a TMDB mapping — it
  ///   refuses sandboxed iframes ("Remove sandbox to use it") and
  ///   answers 410 with no Referer, so it plays unsandboxed with the
  ///   origin sent, ads included. When it answers with its 410 card
  ///   the probe advances to the next server.
  ///
  /// AniXo used to sit between the last two, but it is only a scraper
  /// relay over MegaPlay behind a bot-check ticket that embedded
  /// players cannot pass reliably — and it ships its own popunder ad
  /// tag — so it is no longer offered. VidLink's anime embeds 404
  /// sitewide since Sep 2026, so it is no longer offered either.
  /// A remembered AniXo/VidLink choice simply falls back to Everglow
  /// (see [defaultServerIndex]).
  ///
  /// Picks the TMDB id for titles ani.zip can't map, via a strict
  /// catalog search: the kind must match (`movie` for films, `tv`
  /// otherwise), the normalized title must equal, and the year must
  /// equal when both sides know it. Anything looser risks opening the
  /// wrong film for Clair, so near-misses return null (server stays
  /// hidden) instead of guessing.
  @visibleForTesting
  static int? pickTmdbFallbackId({
    required List<MediaItem> results,
    required String title,
    required String year,
    required bool isMovie,
  }) {
    String norm(String s) =>
        s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final want = norm(title);
    if (want.isEmpty) return null;
    final wantKind = isMovie ? 'movie' : 'tv';
    final wantYear = year.trim();
    for (final r in results) {
      if (r.tmdbId <= 0) continue;
      if (r.mediaType.trim().toLowerCase() != wantKind) continue;
      if (norm(r.title) != want) continue;
      final gotYear = r.year.trim();
      if (wantYear.isNotEmpty && gotYear.isNotEmpty && gotYear != wantYear) {
        continue;
      }
      return r.tmdbId;
    }
    return null;
  }

  /// [episodeSlots] maps a MAL episode number to the season/episode
  /// pair TMDB expects — shows whose MAL entry starts mid-series (e.g.
  /// Attack on Titan season 2) would otherwise open the wrong episode.
  /// [isMovie] switches the TMDB-keyed server to the movie endpoint:
  /// films (e.g. Drifting Home) have a movie TMDB id, and the TV
  /// endpoint with that id opens nothing.
  static List<AnimeServerOption> buildServers({
    int? anilistId,
    int? malId,
    int? tmdbId,
    Map<int, ({int season, int episode})> episodeSlots = const {},
    bool isMovie = false,
  }) {
    final hasAni = anilistId != null && anilistId > 0;
    final effectiveMal = malId ?? 0;
    final effectiveTmdb = tmdbId ?? 0;
    final aniId = hasAni ? anilistId : 0;

    final hasSource = hasAni || effectiveMal > 0;

    return [
      AnimeServerOption(
        name: 'Everglow',
        urlBuilder: (ep, audio) {
          if (isMovie) {
            return 'https://everglow-1c6db.web.app/embed.html'
                '?tmdbId=$effectiveTmdb&type=movie';
          }
          final slot = episodeSlots[ep];
          final season = slot?.season ?? 1;
          final episode = slot?.episode ?? ep;
          return 'https://everglow-1c6db.web.app/embed.html'
              '?tmdbId=$effectiveTmdb&type=tv&s=$season&e=$episode';
        },
        available: effectiveTmdb > 0,
      ),
      AnimeServerOption(
        name: 'Megavid',
        urlBuilder: (ep, audio) => AnimeXWatchPage.megavidProxyUrl(
          anilistId: aniId,
          malId: effectiveMal,
          episode: ep,
          audio: audio,
        ),
        available: hasSource,
      ),
      AnimeServerOption(
        name: 'MegaPlay',
        urlBuilder: (ep, audio) {
          if (hasAni) {
            return 'https://megaplay.buzz/stream/ani/$aniId/$ep/$audio';
          }
          return 'https://megaplay.buzz/stream/mal/$effectiveMal/$ep/$audio';
        },
        available: hasSource,
      ),
    ];
  }

  @override
  State<AnimeXWatchPage> createState() => _AnimeXWatchPageState();
}
