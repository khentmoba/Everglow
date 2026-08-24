import 'package:cloud_firestore/cloud_firestore.dart';

/// Manga / Manhwa / Manhua catalog item, sourced from the Comick API
/// for discovery and MangaKakalot for chapter pages.
///
/// Primary identifier is the Comick `hid` (hashed string), stored as
/// `mangaId`. The `mangaKakalotId` field stores the MangaKakalot slug
/// for chapter resolution.
///
/// `originalLanguage` maps from Comick's `country` field:
///   `jp` = Manga, `ko` = Manhwa, `cn`/`zh` = Manhua.
class MangaItem {
  final String id;
  final String mangaId;
  final String title;
  final String author;
  final String artist;
  final String description;
  final String coverUrl;
  final String year;
  final String status;

  /// `jp` = Manga, `ko` = Manhwa, `cn` = Manhua, `en` etc.
  final String originalLanguage;
  final String contentRating;
  final List<String> tags;
  final String userName;
  final DateTime addedAt;

  /// Owning user. Items in `manga_library` are scoped per user so Khent,
  /// Clair, and Breyan each see only their own library.
  final String libraryStatus;

  /// Last chapter id the user has read (for "Continue Reading" UX).
  final String lastReadChapterId;

  /// 1-indexed page within `lastReadChapterId`.
  final int lastReadPage;

  // ── Comick-specific fields ──────────────────────────────

  /// Comick numeric database ID (0 if not set).
  final int comickId;

  /// Comick URL slug for the comic (empty if not set).
  final String comickSlug;

  /// MangaKakalot slug for chapter page resolution.
  final String mangaKakalotId;

  /// Comick bayesian rating (0.0–10.0 scale).
  final double rating;

  /// Comick user follow count (popularity metric).
  final int followCount;

  /// Alternative titles from MangaDex (English, Japanese, etc.).
  /// Used for fallback title matching when searching MangaKakalot,
  /// MangaKatana, and Comick by title.
  final List<String> altTitles;

  const MangaItem({
    required this.id,
    required this.mangaId,
    required this.title,
    this.author = '',
    this.artist = '',
    this.description = '',
    this.coverUrl = '',
    this.year = '',
    this.status = '',
    this.originalLanguage = 'jp',
    this.contentRating = 'safe',
    this.tags = const [],
    this.userName = '',
    required this.addedAt,
    this.libraryStatus = 'none',
    this.lastReadChapterId = '',
    this.lastReadPage = 0,
    this.comickId = 0,
    this.comickSlug = '',
    this.mangaKakalotId = '',
    this.rating = 0.0,
    this.followCount = 0,
    this.altTitles = const [],
  });

  /// Convenience label for the content type. Used in poster cards and
  /// filters. Falls back to "Manga" for anything outside ja/ko/zh.
  String get contentType {
    switch (originalLanguage) {
      case 'ko':
        return 'Manhwa';
      case 'zh':
      case 'cn':
        return 'Manhua';
      case 'ja':
      case 'jp':
        return 'Manga';
      default:
        return 'Other';
    }
  }

  bool get isInLibrary => libraryStatus != 'none' && libraryStatus.isNotEmpty;
  bool get isReading => libraryStatus == 'reading';
  bool get isPlanToRead => libraryStatus == 'plan-to-read';
  bool get isCompleted => libraryStatus == 'completed';
  bool get isOnHold => libraryStatus == 'on-hold';
  bool get isDropped => libraryStatus == 'dropped';

  String get libraryDisplay {
    switch (libraryStatus) {
      case 'reading':
        return 'Reading';
      case 'plan-to-read':
        return 'Plan to Read';
      case 'completed':
        return 'Completed';
      case 'on-hold':
        return 'On Hold';
      case 'dropped':
        return 'Dropped';
      default:
        return 'Add to Library';
    }
  }

  factory MangaItem.fromFirestore(
    Map<String, dynamic> data,
    String documentId,
  ) {
    return MangaItem(
      id: documentId,
      mangaId: data['mangaId'] ?? '',
      title: data['title'] ?? '',
      author: data['author'] ?? '',
      artist: data['artist'] ?? '',
      description: data['description'] ?? '',
      coverUrl: data['coverUrl'] ?? '',
      year: data['year'] ?? '',
      status: data['status'] ?? '',
      originalLanguage: data['originalLanguage'] ?? 'jp',
      contentRating: data['contentRating'] ?? 'safe',
      tags:
          (data['tags'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
      userName: data['userName'] ?? '',
      addedAt: _parseDateTime(data['addedAt']),
      libraryStatus: data['libraryStatus'] ?? 'none',
      lastReadChapterId: data['lastReadChapterId'] ?? '',
      lastReadPage: (data['lastReadPage'] as num?)?.toInt() ?? 0,
      comickId: (data['comickId'] as num?)?.toInt() ?? 0,
      comickSlug: data['comickSlug'] ?? '',
      mangaKakalotId: data['mangaKakalotId'] ?? data['mangaDexId'] ?? '',
      rating: (data['rating'] as num?)?.toDouble() ?? 0.0,
      followCount: (data['followCount'] as num?)?.toInt() ?? 0,
      altTitles:
          (data['altTitles'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
    );
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (_) {
        return DateTime.now();
      }
    }
    return DateTime.now();
  }

  Map<String, dynamic> toFirestore() {
    return {
      'mangaId': mangaId,
      'title': title,
      'author': author,
      'artist': artist,
      'description': description,
      'coverUrl': coverUrl,
      'year': year,
      'status': status,
      'originalLanguage': originalLanguage,
      'contentRating': contentRating,
      'tags': tags,
      'userName': userName,
      'addedAt': Timestamp.fromDate(addedAt),
      'libraryStatus': libraryStatus,
      'lastReadChapterId': lastReadChapterId,
      'lastReadPage': lastReadPage,
      'comickId': comickId,
      'comickSlug': comickSlug,
      'mangaKakalotId': mangaKakalotId,
      'rating': rating,
      'followCount': followCount,
      'altTitles': altTitles,
    };
  }

  MangaItem copyWith({
    String? id,
    String? mangaId,
    String? title,
    String? author,
    String? artist,
    String? description,
    String? coverUrl,
    String? year,
    String? status,
    String? originalLanguage,
    String? contentRating,
    List<String>? tags,
    String? userName,
    DateTime? addedAt,
    String? libraryStatus,
    String? lastReadChapterId,
    int? lastReadPage,
    int? comickId,
    String? comickSlug,
    String? mangaKakalotId,
    double? rating,
    int? followCount,
    List<String>? altTitles,
  }) {
    return MangaItem(
      id: id ?? this.id,
      mangaId: mangaId ?? this.mangaId,
      title: title ?? this.title,
      author: author ?? this.author,
      artist: artist ?? this.artist,
      description: description ?? this.description,
      coverUrl: coverUrl ?? this.coverUrl,
      year: year ?? this.year,
      status: status ?? this.status,
      originalLanguage: originalLanguage ?? this.originalLanguage,
      contentRating: contentRating ?? this.contentRating,
      tags: tags ?? this.tags,
      userName: userName ?? this.userName,
      addedAt: addedAt ?? this.addedAt,
      libraryStatus: libraryStatus ?? this.libraryStatus,
      lastReadChapterId: lastReadChapterId ?? this.lastReadChapterId,
      lastReadPage: lastReadPage ?? this.lastReadPage,
      comickId: comickId ?? this.comickId,
      comickSlug: comickSlug ?? this.comickSlug,
      mangaKakalotId: mangaKakalotId ?? this.mangaKakalotId,
      rating: rating ?? this.rating,
      followCount: followCount ?? this.followCount,
      altTitles: altTitles ?? this.altTitles,
    );
  }
}

/// A single chapter of a manga. Sourced from MangaKakalot.
/// We surface the minimum needed for both the chapter list and the
/// reader (title, number, volume, language, page count, scanlation
/// group name).
class MangaChapter {
  final String id;
  final String title;
  final String chapter;
  final String volume;
  final int pages;
  final String translatedLanguage;
  final String scanlationGroup;
  final DateTime publishAt;

  const MangaChapter({
    required this.id,
    this.title = '',
    this.chapter = '',
    this.volume = '',
    this.pages = 0,
    this.translatedLanguage = 'en',
    this.scanlationGroup = '',
    required this.publishAt,
  });

  /// Display label: "Ch. 15 — The Battle Begins". Falls back to the
  /// raw chapter id if no number is available.
  String get displayTitle {
    final parts = <String>[];
    if (chapter.isNotEmpty) parts.add('Ch. $chapter');
    if (title.isNotEmpty) parts.add(title);
    if (parts.isEmpty) return id;
    return parts.join(' — ');
  }

  /// Short label for compact lists: "Ch. 15" or "Oneshot".
  String get shortLabel {
    if (chapter.isEmpty) return 'Oneshot';
    return 'Ch. $chapter';
  }

  factory MangaChapter.fromApi(
    Map<String, dynamic> attrs,
    Map<String, dynamic> rels,
  ) {
    final relationships = rels['relationships'] as List? ?? [];
    String group = '';
    for (final rel in relationships) {
      if (rel is Map && rel['type'] == 'scanlation_group') {
        group = (rel['attributes']?['name'] as String?) ?? '';
        break;
      }
    }
    return MangaChapter(
      id: rels['id'] as String? ?? '',
      title: (attrs['title'] as String?) ?? '',
      chapter: (attrs['chapter'] as String?) ?? '',
      volume: (attrs['volume'] as String?) ?? '',
      pages: (attrs['pages'] as num?)?.toInt() ?? 0,
      translatedLanguage: (attrs['translatedLanguage'] as String?) ?? 'en',
      scanlationGroup: group,
      publishAt:
          DateTime.tryParse((attrs['publishAt'] as String?) ?? '') ??
          DateTime.now(),
    );
  }
}

/// Resolved page image URLs for a chapter. Returned by
/// `MangaKakalotService.getChapterPages` and consumed by `MangaReaderScreen`.
class MangaChapterPages {
  final String chapterId;
  final String baseUrl;
  final String hash;
  final List<String> filenames;
  final DateTime expiresAt;

  const MangaChapterPages({
    required this.chapterId,
    required this.baseUrl,
    required this.hash,
    required this.filenames,
    required this.expiresAt,
  });

  /// Build the full image URL for the given 0-indexed page.
  /// When [baseUrl] is empty, [filenames] are treated as direct URLs.
  String urlForPage(int index) {
    if (index < 0 || index >= filenames.length) return '';
    if (baseUrl.isEmpty) return filenames[index];
    return '$baseUrl/data/$hash/${filenames[index]}';
  }
}
