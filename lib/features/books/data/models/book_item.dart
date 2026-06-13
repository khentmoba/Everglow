import 'package:cloud_firestore/cloud_firestore.dart';

/// Universal book model — used for both personal "to-read / read" lists
/// and the search results from Open Library. Mirrors the
/// [MediaItem] shape used by the cinema feature so future shared
/// widgets stay consistent.
///
/// We store an Open Library "work key" (e.g. `/works/OL45804W`) as
/// the primary identifier because editions can proliferate but the
/// work is canonical. We also persist an optional Internet Archive
/// id (the `ia` field returned by Open Library's search API) so the
/// reader can locate a borrowable full-text copy.
class BookItem {
  final String id;
  final String workKey;
  final String editionKey;
  final String iaId;
  final String title;
  final String author;
  final String coverUrl;
  final String year;
  final int pageCount;
  final List<String> subjects;
  final String status;

  /// Owning user. Items in `read_list` are scoped per user so Khent,
  /// Clair, and Breyan each see only their own queue / history.
  final String userName;
  final DateTime addedAt;

  /// Where to read this book. Resolved by [OpenLibraryService] and
  /// stored on the model so the reader can hit a single source URL
  /// (Gutenberg plain text, IA djvu text, etc.) without re-deriving.
  final String readSourceUrl;

  /// Hint about which provider powers the read source. Used to label
  /// the reader chrome ("Gutenberg", "Internet Archive", "Open
  /// Library", etc.). Not stored in Firestore.
  final String readSourceLabel;

  const BookItem({
    required this.id,
    required this.workKey,
    this.editionKey = '',
    this.iaId = '',
    required this.title,
    this.author = '',
    this.coverUrl = '',
    this.year = '',
    this.pageCount = 0,
    this.subjects = const [],
    required this.status,
    this.userName = '',
    required this.addedAt,
    this.readSourceUrl = '',
    this.readSourceLabel = '',
  });

  bool get isRead =>
      status == 'read' ||
      status == 'read-khent' ||
      status == 'read-clair' ||
      status == 'read-both' ||
      status == 'read-self';

  bool get isToRead => status == 'to-read';

  String get readDisplay {
    if (status == 'read-khent') return 'Read by Khent';
    if (status == 'read-clair') return 'Read by Clair';
    if (status == 'read-both' || status == 'read') return 'Read by Both';
    if (status == 'read-self') return 'Read';
    return 'To Read';
  }

  /// Open Library cover URL helper. Returns the supplied URL if it
  /// already starts with `http`, otherwise derives the standard CDN
  /// URL from the cover id.
  static String coverFromCoverId(int? coverId, {String size = 'L'}) {
    if (coverId == null || coverId <= 0) return '';
    return 'https://covers.openlibrary.org/b/id/$coverId-$size.jpg';
  }

  /// Open Library cover URL by work key (`OL...W`).
  static String coverFromOlid(String? olid, {String size = 'L'}) {
    if (olid == null || olid.isEmpty) return '';
    return 'https://covers.openlibrary.org/b/olid/$olid-$size.jpg';
  }

  factory BookItem.fromFirestore(Map<String, dynamic> data, String documentId) {
    final subjectsRaw = data['subjects'];
    final subjects = subjectsRaw is List
        ? subjectsRaw.map((e) => e.toString()).toList()
        : const <String>[];
    final iaId = data['iaId'] ?? '';
    final workKey = data['workKey'] ?? '';
    return BookItem(
      id: documentId,
      workKey: workKey,
      editionKey: data['editionKey'] ?? '',
      iaId: iaId,
      title: data['title'] ?? '',
      author: data['author'] ?? '',
      coverUrl: data['coverUrl'] ?? '',
      year: data['year'] ?? '',
      pageCount: (data['pageCount'] as num?)?.toInt() ?? 0,
      subjects: subjects,
      status: data['status'] ?? 'to-read',
      userName: data['userName'] ?? '',
      addedAt: _parseDateTime(data['addedAt']),
      // Persist the source URL so the reader can hit a single
      // address after a round-trip through Firestore. If the field
      // is missing on a legacy document we re-derive it from the
      // `iaId` / `workKey` instead of leaving the reader stranded.
      readSourceUrl: data['readSourceUrl'] ??
          deriveReadSourceUrl(iaId: iaId, workKey: workKey),
      readSourceLabel: data['readSourceLabel'] ??
          deriveReadSourceLabel(iaId: iaId),
    );
  }

  /// Re-derive the read source URL when no explicit one was stored.
  /// Mirrors the logic in `OpenLibraryService._resolveReadSources`
  /// so the model stays self-sufficient after a Firestore round-trip.
  static String deriveReadSourceUrl({
    required String iaId,
    required String workKey,
  }) {
    if (iaId.isNotEmpty && iaId.startsWith('pg') && iaId.length > 2) {
      final id = iaId.substring(2);
      return 'https://www.gutenberg.org/cache/epub/$id/pg$id.txt';
    }
    if (iaId.isNotEmpty) {
      return 'https://archive.org/download/$iaId/${iaId}_djvu.txt';
    }
    if (workKey.isNotEmpty) {
      return 'https://openlibrary.org$workKey';
    }
    return '';
  }

  static String deriveReadSourceLabel({required String iaId}) {
    if (iaId.startsWith('pg')) return 'Project Gutenberg';
    if (iaId.isNotEmpty) return 'Internet Archive';
    return 'Open Library';
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
      'workKey': workKey,
      'editionKey': editionKey,
      'iaId': iaId,
      'title': title,
      'author': author,
      'coverUrl': coverUrl,
      'year': year,
      'pageCount': pageCount,
      'subjects': subjects,
      'status': status,
      'userName': userName,
      'addedAt': Timestamp.fromDate(addedAt),
      // Persist the resolved read source so the reader can find it
      // after a round-trip. Without this, [fromFirestore] would
      // always return an empty URL and the reader would refuse to
      // load the book.
      'readSourceUrl': readSourceUrl,
      'readSourceLabel': readSourceLabel,
    };
  }

  BookItem copyWith({
    String? id,
    String? workKey,
    String? editionKey,
    String? iaId,
    String? title,
    String? author,
    String? coverUrl,
    String? year,
    int? pageCount,
    List<String>? subjects,
    String? status,
    String? userName,
    DateTime? addedAt,
    String? readSourceUrl,
    String? readSourceLabel,
  }) {
    return BookItem(
      id: id ?? this.id,
      workKey: workKey ?? this.workKey,
      editionKey: editionKey ?? this.editionKey,
      iaId: iaId ?? this.iaId,
      title: title ?? this.title,
      author: author ?? this.author,
      coverUrl: coverUrl ?? this.coverUrl,
      year: year ?? this.year,
      pageCount: pageCount ?? this.pageCount,
      subjects: subjects ?? this.subjects,
      status: status ?? this.status,
      userName: userName ?? this.userName,
      addedAt: addedAt ?? this.addedAt,
      readSourceUrl: readSourceUrl ?? this.readSourceUrl,
      readSourceLabel: readSourceLabel ?? this.readSourceLabel,
    );
  }
}
