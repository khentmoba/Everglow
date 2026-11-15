import 'package:cloud_firestore/cloud_firestore.dart';

import 'chapter_num.dart';

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

String katanaChapterNumFromId(String id) {
  if (id == 'fc') return '';
  final lower = id.toLowerCase();
  final cIndex = lower.lastIndexOf('c');
  if (cIndex < 0 || cIndex == lower.length - 1) return '';
  return lower.substring(cIndex + 1);
}

String katanaLanguageForGenres(List<KatanaGenre> genres) {
  var manhwa = false;
  for (final genre in genres) {
    final slug = genre.slug.toLowerCase();
    final name = genre.name.toLowerCase();
    if (slug == 'manhua' || name == 'manhua') return 'cn';
    if (slug == 'manhwa' || name == 'manhwa') manhwa = true;
  }
  return manhwa ? 'ko' : 'jp';
}

class KatanaChapter {
  final String id;
  final String num;
  final String title;
  final DateTime? updateAt;
  final bool isNew;

  const KatanaChapter({
    required this.id,
    required this.num,
    required this.title,
    this.updateAt,
    this.isNew = false,
  });

  String get path => id;

  bool get isFirst => id == 'fc';

  String get displayTitle {
    if (title.isNotEmpty) return title;
    if (num.isNotEmpty) return 'Chapter $num';
    return 'Chapter';
  }

  double get numeric => chapterNumValue(num);
}

class KatanaManga {
  final String slug;
  final String id;
  final String title;
  final String coverUrl;
  final String status;
  final String updateText;
  final String summary;
  final List<KatanaGenre> genres;
  final KatanaChapter? latestChapter;
  final List<KatanaChapter> recentChapters;

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
  final String recommendedBy;
  final String recommendationNote;

  final Set<String> readChapterIds;

  final bool bookmarked;

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
    this.recommendedBy = '',
    this.recommendationNote = '',
    this.readChapterIds = const {},
    this.bookmarked = true,
  });

  bool get hasProgress => lastReadChapterId.isNotEmpty;
  bool get isRecommended => recommendedBy.isNotEmpty;
  bool get isBookmarked => bookmarked;

  factory KatanaBookmark.fromFirestore(
    Map<String, dynamic> data,
    String documentId,
  ) {
    final read = data['readChapterIds'];
    return KatanaBookmark(
      slug: _toStr(data['slug'], fallback: documentId),
      title: _toStr(data['title']),
      coverUrl: _toStr(data['coverUrl']),
      status: _toStr(data['status'], fallback: 'ongoing'),
      addedAt: _parseDate(data['addedAt']),
      lastReadChapterId: _toStr(data['lastReadChapterId']),
      lastReadPage: _toInt(data['lastReadPage']),
      lastReadChapterTitle: _toStr(data['lastReadChapterTitle']),
      latestChapterTitle: _toStr(data['latestChapterTitle']),
      recommendedBy: _toStr(data['recommendedBy']),
      recommendationNote: _toStr(data['recommendationNote']),
      readChapterIds: read is List
          ? {for (final id in read) if (id is String && id.isNotEmpty) id}
          : const {},
      bookmarked: data['bookmarked'] != false,
    );
  }

  static String _toStr(dynamic value, {String fallback = ''}) =>
      value is String ? value : fallback;

  static int _toInt(dynamic value) => value is num ? value.toInt() : 0;

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
      'recommendedBy': recommendedBy,
      'recommendationNote': recommendationNote,
      'readChapterIds': readChapterIds.toList(),
      'bookmarked': bookmarked,
    };
  }

  static DateTime _parseDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return DateTime.now();
  }
}

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

class KatanaHomeData {
  final List<KatanaManga> hotUpdates;
  final List<KatanaManga> latest;
  final List<KatanaManga> hot;
  final List<KatanaGenre> genres;

  const KatanaHomeData({
    this.hotUpdates = const [],
    this.latest = const [],
    this.hot = const [],
    this.genres = const [],
  });
}
