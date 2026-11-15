part of 'animex_watch_page.dart';

class AnimeServerOption {
  final String name;
  final String Function(int episode, String audio) urlBuilder;
  final bool available;
  final bool supportsAudioSelection;
  final bool supportsSeek;
  final bool supportsResume;

  final String tag;

  const AnimeServerOption({
    required this.name,
    required this.urlBuilder,
    this.available = true,
    this.supportsAudioSelection = true,
    this.supportsSeek = false,
    this.supportsResume = false,
    this.tag = '',
  });

  String urlFor(int episode, String audio, {int? startSeconds}) {
    final url = urlBuilder(episode, audio);
    if (!supportsResume || startSeconds == null || startSeconds <= 0) {
      return url;
    }
    final uri = Uri.parse(url);
    return uri
        .replace(
          queryParameters: {...uri.queryParameters, 'start': '$startSeconds'},
        )
        .toString();
  }
}

typedef _ServerOption = AnimeServerOption;

class AnimeXWatchPage extends StatefulWidget {
  final AnimeXController controller;

  final Future<MediaItem?> Function(MediaItem item)? loadSavedProgress;

  const AnimeXWatchPage({
    super.key,
    required this.controller,
    this.loadSavedProgress,
  });

  @visibleForTesting
  static ({int episode, int? seconds}) resolveResume({
    required MediaItem item,
    MediaItem? saved,
    AnimexHistoryEntry? local,
    int? requestedEpisode,
  }) {
    final progress = saved ?? item;
    final accountIsAuthoritative =
        saved != null &&
        (saved.progressUpdatedAt != null ||
            saved.currentEpisode != null ||
            saved.currentTimestamp != null ||
            saved.isWatched);
    final completedEpisode =
        !progress.isMovie &&
        (progress.durationSeconds ?? 0) > 0 &&
        (progress.currentTimestamp ?? 0) >= progress.durationSeconds! * 0.95 &&
        (progress.currentEpisode ?? 0) > 0 &&
        (progress.currentEpisode ?? 0) < (progress.episodeCount ?? 0);
    final episode =
        requestedEpisode ??
        (progress.isWatched
            ? 1
            : completedEpisode
            ? progress.currentEpisode! + 1
            : progress.currentEpisode) ??
        (accountIsAuthoritative ? 1 : local?.episode) ??
        1;
    final sameEpisode = progress.isMovie || progress.currentEpisode == episode;
    return (
      episode: episode > 0 ? episode : 1,
      seconds: sameEpisode ? progress.resumeSeconds : null,
    );
  }

  @visibleForTesting
  static bool skipGuidanceVisible(
    AniSkipTime? time,
    double? observedPosition, {
    required bool supportsSeek,
  }) {
    if (time == null) return false;
    return !supportsSeek ||
        observedPosition == null ||
        skipVisibleAt(time, observedPosition);
  }

  @visibleForTesting
  static ({String token, bool isSeason})? nextUp({
    required bool isFilm,
    required int selectedEpisode,
    required int episodeCount,
    required bool hasNextSeason,
  }) {
    if (!isFilm && selectedEpisode < episodeCount) {
      return (token: 'EP ${selectedEpisode + 1}', isSeason: false);
    }
    if (hasNextSeason) return (token: '', isSeason: true);
    return null;
  }

  static bool isProviderErrorPage(String body) {
    final lower = body.toLowerCase();
    return lower.contains('error code: <span>410</span>') ||
        lower.contains('error - megaplay') ||
        lower.contains('no playable stream sources') ||
        lower.contains('no playable stream') ||
        lower.contains('no video sources found') ||
        lower.contains('stream not found') ||
        lower.contains('could not resolve stream') ||
        lower.contains('tryembed_sandbox_blocked') ||
        lower.contains('leech block engaged') ||
        lower.contains('leech protection engaged') ||
        lower.contains('403 forbidden') ||
        lower.contains('this page could not be found') ||
        lower.contains("coudn't find this episode") ||
        lower.contains("couldn't find this episode") ||
        (lower.contains('410') && lower.contains('copyright violation'));
  }

  static String normalizeServerName(String? name) {
    if (name == null) return '';
    switch (name) {
      case 'Server 1':
        return 'Everglow';
      case 'Server 2':
        return 'VidLink';
      case 'Server 3':
      case 'Megavid':
      case 'Yume':
        return 'Everglow';
      case 'Mega Play':
      case 'MegaPlay':
        return 'Everglow';
      case 'Anixo':
        return 'AniXo';
      default:
        return name;
    }
  }

  @visibleForTesting
  static int resolveMappingsMalId({int? detailMalId, required int routeMalId}) {
    if (detailMalId != null && detailMalId > 0) return detailMalId;
    return routeMalId;
  }

  static final _seasonInTitleRegex = RegExp(
    r'season\s+(\d+)',
    caseSensitive: false,
  );

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

  static const String proxyAnimeBase =
      'https://everglow-stream.khentplaysmoba.workers.dev/proxyAnime';

  @visibleForTesting
  static String everglowProxyUrl({
    required int anilistId,
    required int malId,
    required int episode,
    required String audio,
  }) {
    return '$proxyAnimeBase?source=everglow'
        '&anilistId=$anilistId&malId=$malId&ep=$episode&audio=$audio';
  }

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
    final tracked = servers.indexWhere(
      (s) => s.available && s.name == 'Everglow',
    );
    if (tracked != -1) return tracked;
    final first = servers.indexWhere((s) => s.available);
    return first == -1 ? 0 : first;
  }

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
        tag: 'Ad-free',
        urlBuilder: (ep, audio) => AnimeXWatchPage.everglowProxyUrl(
          anilistId: aniId,
          malId: effectiveMal,
          episode: ep,
          audio: audio,
        ),
        available: hasSource,
        supportsSeek: true,
        supportsResume: true,
      ),
      AnimeServerOption(
        name: 'CineSrc',
        tag: 'Ad-free',
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
        supportsAudioSelection: false,
        supportsResume: true,
      ),
      AnimeServerOption(
        name: 'TryEmbed',
        tag: 'Embed',
        urlBuilder: (ep, audio) {
          if (hasAni) {
            return 'https://tryembed.us.cc/embed/anime/$aniId/$ep/$audio';
          }
          return 'https://tryembed.us.cc/embed/anime/$effectiveMal/$ep/$audio?type=mal';
        },
        available: hasSource,
      ),
      AnimeServerOption(
        name: 'VidCore',
        tag: 'Embed',
        urlBuilder: (ep, audio) {
          if (isMovie) {
            return 'https://vidcore.org/embed/movie/$effectiveTmdb';
          }
          final slot = episodeSlots[ep];
          final season = slot?.season ?? 1;
          final episode = slot?.episode ?? ep;
          return 'https://vidcore.org/embed/tv/$effectiveTmdb/$season/$episode';
        },
        available: effectiveTmdb > 0,
        supportsAudioSelection: false,
      ),
      AnimeServerOption(
        name: 'Rive',
        tag: 'Embed',
        urlBuilder: (ep, audio) {
          if (isMovie) {
            return 'https://rivestream.us/embed?type=movie&id=$effectiveTmdb';
          }
          final slot = episodeSlots[ep];
          final season = slot?.season ?? 1;
          final episode = slot?.episode ?? ep;
          return 'https://rivestream.us/embed?type=tv&id=$effectiveTmdb&season=$season&episode=$episode';
        },
        available: effectiveTmdb > 0,
        supportsAudioSelection: false,
      ),
      AnimeServerOption(
        name: 'Fmov',
        tag: 'Embed',
        urlBuilder: (ep, audio) {
          if (isMovie) {
            return 'https://fmov.my/embed/movie/$effectiveTmdb';
          }
          final slot = episodeSlots[ep];
          final season = slot?.season ?? 1;
          final episode = slot?.episode ?? ep;
          return 'https://fmov.my/embed/anime/$effectiveTmdb/$season/$episode';
        },
        available: effectiveTmdb > 0,
        supportsAudioSelection: false,
      ),
    ];
  }

  @visibleForTesting
  static List<AniListEpisode> buildEpisodeList({
    AniListDetail? detail,
    int? fallbackEpisodeCount,
    Map<int, Map<String, dynamic>> aniZipEpisodes = const {},
  }) {
    final fromDetail = detail?.episodes ?? const <AniListEpisode>[];
    final detailMap = <int, AniListEpisode>{
      for (final e in fromDetail) e.number: e,
    };
    final count = detail?.episodeCount ?? fallbackEpisodeCount ?? 0;
    final maxNum = [
      count,
      if (count <= 0 && detailMap.isNotEmpty)
        detailMap.keys.reduce((a, b) => a > b ? a : b),
      if (count <= 0 && aniZipEpisodes.isNotEmpty)
        aniZipEpisodes.keys.reduce((a, b) => a > b ? a : b),
    ].fold<int>(0, (a, b) => a > b ? a : b);

    return List.generate(maxNum > 0 ? maxNum : 12, (index) {
      final number = index + 1;
      final base = detailMap[number];
      final az = aniZipEpisodes[number];
      final titles = az?['title'] as Map<String, dynamic>?;
      final azEnglish = titles?['en'] as String?;
      final azJat = titles?['x-jat'] as String?;
      final azJapanese = titles?['ja'] as String?;
      final baseTitle = base?.title;
      final title = (azEnglish != null && azEnglish.isNotEmpty)
          ? azEnglish
          : (baseTitle != null &&
                baseTitle.isNotEmpty &&
                !baseTitle.toLowerCase().startsWith('episode $number'))
          ? baseTitle
          : (azJat ?? baseTitle ?? 'Episode $number');
      final rawAir = az?['airDate'] ?? az?['airdate'];
      final azImage = az?['image'] as String?;
      final rawDuration = az?['runtime'] ?? az?['length'];

      return AniListEpisode(
        number: number,
        title: title,
        titleRomaji: base?.titleRomaji ?? azJat ?? azJapanese,
        synopsis: (base?.synopsis?.isNotEmpty == true)
            ? base!.synopsis
            : ((az?['overview'] as String?)?.isNotEmpty == true
                  ? az!['overview'] as String?
                  : az?['summary'] as String?),
        airedAt:
            base?.airedAt ??
            (rawAir is String ? DateTime.tryParse(rawAir) : null),
        duration:
            base?.duration ??
            (rawDuration is num ? rawDuration.toInt() : null) ??
            detail?.duration,
        thumbnail: (azImage != null && azImage.isNotEmpty)
            ? azImage
            : base?.thumbnail,
      );
    });
  }

  @override
  State<AnimeXWatchPage> createState() => _AnimeXWatchPageState();
}
