import 'package:cloud_firestore/cloud_firestore.dart';

import 'chapter_num.dart';

/// Models for the Manga Katana catalog clone.
///
/// Everything here is scraped from `mangakatana.com` and mirrors the
/// site's own data shape: manga entries, chapters, genres, and the
/// user bookmark record (stored in Firestore per Everglow user).

/// A single genre / tag on Manga Katana.
class KatanaGenre {
  final String slug;
  final String name;
  final int count;
  final String description;

  const KatanaGenre({
    required this.slug,
    required this.name,
    this.count = 0,
    this.description = '',
  });
}

/// A single chapter entry for a manga (e.g. `c413`).
class KatanaChapter {
  final String id;
  final String num;
  final String title;
  final DateTime? updateAt;

  const KatanaChapter({
    required this.id,
    required this.num,
    required this.title,
    this.updateAt,
  });

  /// MangaKatana chapter path, e.g. `c413` or `fc`.
  String get path => id;

  bool get isFirst => id == 'fc';

  String get displayTitle {
    if (title.isNotEmpty) return title;
    if (num.isNotEmpty) return 'Chapter $num';
    return 'Chapter';
  }

  double get numeric => chapterNumValue(num);
}

/// A manga entry from the Manga Katana catalog.
///
/// List items only populate [latestChapter], [genres], [summary],
/// [updateText] and [recentChapters]; the detail page additionally
/// populates [altNames], [authors], [artists], [chapters] and
/// [description].
class KatanaManga {
  final String slug;
  final String id;
  final String title;
  final String coverUrl;
  final String status; // 'ongoing' | 'completed'
  final String updateText; // e.g. "58 minutes ago"
  final String summary;
  final List<KatanaGenre> genres;
  final KatanaChapter? latestChapter;
  final List<KatanaChapter> recentChapters;

  // Detail-only fields
  final List<String> altNames;
  final List<String> authors;
  final List<String> artists;
  final List<KatanaChapter> chapters;
  final DateTime? updateAt;

  const KatanaManga({
    required this.slug,
    required this.id,
    required this.title,
    required this.coverUrl,
    this.status = 'ongoing',
    this.updateText = '',
    this.summary = '',
    this.genres = const [],
    this.latestChapter,
    this.recentChapters = const [],
    this.altNames = const [],
    this.authors = const [],
    this.artists = const [],
    this.chapters = const [],
    this.updateAt,
  });

  bool get isCompleted => status == 'completed';

  KatanaManga copyWith({
    String? coverUrl,
    String? status,
    String? updateText,
    String? summary,
    List<KatanaGenre>? genres,
    KatanaChapter? latestChapter,
    List<KatanaChapter>? recentChapters,
    List<KatanaChapter>? chapters,
    DateTime? updateAt,
  }) {
    return KatanaManga(
      slug: slug,
      id: id,
      title: title,
      coverUrl: coverUrl ?? this.coverUrl,
      status: status ?? this.status,
      updateText: updateText ?? this.updateText,
      summary: summary ?? this.summary,
      genres: genres ?? this.genres,
      latestChapter: latestChapter ?? this.latestChapter,
      recentChapters: recentChapters ?? this.recentChapters,
      altNames: altNames,
      authors: authors,
      artists: artists,
      chapters: chapters ?? this.chapters,
      updateAt: updateAt ?? this.updateAt,
    );
  }
}

/// A user's bookmarked manga, persisted in Firestore.
class KatanaBookmark {
  final String slug;
  final String title;
  final String coverUrl;
  final String status;
  final DateTime addedAt;
  final String lastReadChapterId;
  final int lastReadPage;
  final String lastReadChapterTitle;
  final String latestChapterTitle;

  const KatanaBookmark({
    required this.slug,
    required this.title,
    required this.coverUrl,
    this.status = 'ongoing',
    required this.addedAt,
    this.lastReadChapterId = '',
    this.lastReadPage = 0,
    this.lastReadChapterTitle = '',
    this.latestChapterTitle = '',
  });

  bool get hasProgress => lastReadChapterId.isNotEmpty;

  factory KatanaBookmark.fromFirestore(
    Map<String, dynamic> data,
    String documentId,
  ) {
    return KatanaBookmark(
      slug: data['slug'] ?? documentId,
      title: data['title'] ?? '',
      coverUrl: data['coverUrl'] ?? '',
      status: data['status'] ?? 'ongoing',
      addedAt: _parseDate(data['addedAt']),
      lastReadChapterId: data['lastReadChapterId'] ?? '',
      lastReadPage: (data['lastReadPage'] as num?)?.toInt() ?? 0,
      lastReadChapterTitle: data['lastReadChapterTitle'] ?? '',
      latestChapterTitle: data['latestChapterTitle'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'slug': slug,
      'title': title,
      'coverUrl': coverUrl,
      'status': status,
      'addedAt': Timestamp.fromDate(addedAt),
      'lastReadChapterId': lastReadChapterId,
      'lastReadPage': lastReadPage,
      'lastReadChapterTitle': lastReadChapterTitle,
      'latestChapterTitle': latestChapterTitle,
    };
  }

  static DateTime _parseDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return DateTime.now();
  }
}

/// A page of catalog results from Manga Katana.
class KatanaPageResult {
  final List<KatanaManga> items;
  final int page;
  final bool hasNext;
  final bool hasPrev;

  const KatanaPageResult({
    required this.items,
    required this.page,
    required this.hasNext,
    required this.hasPrev,
  });
}

/// Aggregated home page data (Latest Updates, Hot Manga, genres).
class KatanaHomeData {
  final List<KatanaManga> latest;
  final List<KatanaManga> hot;
  final List<KatanaGenre> genres;

  const KatanaHomeData({
    this.latest = const [],
    this.hot = const [],
    this.genres = const [],
  });
}
