/// Rich anime metadata returned by [AniListService.fetchDetails].
///
/// Bundles everything the [EpisodeDrawer] needs in one shape: synopsis,
/// character + Japanese-VA cast, staff, related anime, recommendations,
/// episode list, and a YouTube trailer key (AniList's `trailer.site ==
/// 'youtube'` field). All fields are nullable except [id] and [titleEnglish]
/// so callers can show a partial UI if AniList returns a slim payload.
class AniListDetail {
  final int id;
  final int? malId;
  final String titleEnglish;
  final String titleRomaji;
  final String titleNative;
  final String synopsis;
  final String coverImageUrl;
  final String bannerImageUrl;
  final int? episodeCount;
  final int? duration;
  final String airingStatus;
  final String format;
  final String? season;
  final int? seasonYear;
  final double? averageScore;
  final List<String> genres;
  final List<String> studios;
  final String? trailerYoutubeId;
  final List<AniListCharacter> characters;
  final List<AniListStaffMember> staff;
  final List<AniListRelated> relations;
  final List<AniListRecommended> recommendations;
  final List<AniListEpisode> episodes;

  const AniListDetail({
    required this.id,
    this.malId,
    required this.titleEnglish,
    required this.titleRomaji,
    required this.titleNative,
    required this.synopsis,
    required this.coverImageUrl,
    required this.bannerImageUrl,
    this.episodeCount,
    this.duration,
    required this.airingStatus,
    required this.format,
    this.season,
    this.seasonYear,
    this.averageScore,
    this.genres = const [],
    this.studios = const [],
    this.trailerYoutubeId,
    this.characters = const [],
    this.staff = const [],
    this.relations = const [],
    this.recommendations = const [],
    this.episodes = const [],
  });
}

class AniListCharacter {
  final int id;
  final String name;
  final String imageUrl;
  final String role; // MAIN, SUPPORTING, BACKGROUND
  final List<AniListVoiceActor> voiceActors;
  const AniListCharacter({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.role,
    this.voiceActors = const [],
  });
}

class AniListVoiceActor {
  final int id;
  final String name;
  final String imageUrl;
  final String language;
  const AniListVoiceActor({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.language,
  });
}

class AniListStaffMember {
  final int id;
  final String name;
  final String imageUrl;
  final String role;
  const AniListStaffMember({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.role,
  });
}

class AniListRelated {
  final int id;
  final String title;
  final String coverImageUrl;
  final String relationType; // SEQUEL, PREQUEL, SIDE_STORY, etc.
  final String format; // TV, MOVIE, OVA

  /// MAL id for the related title. Critical for routing: the
  /// [EpisodeDrawer] uses `MediaItem.tmdbId` as the MAL id for
  /// anime-sourced items, so the AniList-native `id` alone can't be
  /// looked up — we need the MAL id too. Optional because AniList
  /// sometimes returns a relation node that hasn't been cross-linked
  /// to MAL yet.
  final int? malId;
  const AniListRelated({
    required this.id,
    required this.title,
    required this.coverImageUrl,
    required this.relationType,
    required this.format,
    this.malId,
  });
}

class AniListRecommended {
  final int id;
  final int? malId;
  final String title;
  final String coverImageUrl;
  final int? rating; // AniList user rating, 1-100
  const AniListRecommended({
    required this.id,
    this.malId,
    required this.title,
    required this.coverImageUrl,
    this.rating,
  });
}

class AniListEpisode {
  final int number;
  final String? title;
  final String? titleRomaji;
  final String? synopsis;
  final DateTime? airedAt;
  final int? duration;

  /// Episode still/thumbnail URL from AniList's `streamingEpisodes`
  /// payload. Western-licensed titles often have licensed stills
  /// (Crunchyroll, Funimation, etc.) wired up; for others the field is
  /// null and the episode tile falls back to the anime's poster or a
  /// generated color block.
  final String? thumbnail;
  const AniListEpisode({
    required this.number,
    this.title,
    this.titleRomaji,
    this.synopsis,
    this.airedAt,
    this.duration,
    this.thumbnail,
  });
}
