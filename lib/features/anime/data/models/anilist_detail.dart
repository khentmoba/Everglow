class AniListDetail {
  final int id;
  final int? malId;
  final String titleEnglish;
  final String titleRomaji;
  final String titleNative;
  final String synopsis;
  final String coverImageUrl;
  final String bannerImageUrl;
  final String siteUrl;
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
  final List<AniListSeason> seasons;

  final int? nextAiringAt;

  final int? nextAiringEpisode;

  const AniListDetail({
    required this.id,
    this.malId,
    required this.titleEnglish,
    required this.titleRomaji,
    required this.titleNative,
    required this.synopsis,
    required this.coverImageUrl,
    required this.bannerImageUrl,
    this.siteUrl = '',
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
    this.seasons = const [],
    this.nextAiringAt,
    this.nextAiringEpisode,
  });
}

class AniListCharacter {
  final int id;
  final String name;
  final String imageUrl;
  final String role;
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

class AniListSeason {
  final int id;
  final int? malId;
  final String title;
  final String label;
  final String coverImageUrl;
  final String format;
  final int? year;
  final int month;
  final int day;
  final int? episodeCount;
  final bool isCurrent;

  const AniListSeason({
    required this.id,
    this.malId,
    required this.title,
    String? label,
    required this.coverImageUrl,
    required this.format,
    this.year,
    this.month = 0,
    this.day = 0,
    this.episodeCount,
    this.isCurrent = false,
  }) : label = label ?? title;

  AniListSeason copyWith({
    int? id,
    int? malId,
    String? title,
    String? label,
    String? coverImageUrl,
    String? format,
    int? year,
    int? month,
    int? day,
    int? episodeCount,
    bool? isCurrent,
  }) {
    return AniListSeason(
      id: id ?? this.id,
      malId: malId ?? this.malId,
      title: title ?? this.title,
      label: label ?? this.label,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      format: format ?? this.format,
      year: year ?? this.year,
      month: month ?? this.month,
      day: day ?? this.day,
      episodeCount: episodeCount ?? this.episodeCount,
      isCurrent: isCurrent ?? this.isCurrent,
    );
  }
}

class AniListRelated {
  final int id;
  final String title;
  final String coverImageUrl;
  final String relationType;
  final String format;

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
  final int? rating;
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
