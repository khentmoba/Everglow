import 'package:cloud_firestore/cloud_firestore.dart';

class BookItem {
  final String id;
  final String workKey;
  final String editionKey;
  final String iaId;
  final String title;
  final String author;
  final String coverUrl;
  final String year;
  final String publisher;
  final String isbn;
  final int pageCount;
  final List<String> subjects;
  final String status;

  final String userName;
  final DateTime addedAt;

  final String readSourceUrl;

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
    this.publisher = '',
    this.isbn = '',
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

  static String coverFromCoverId(int? coverId, {String size = 'L'}) {
    if (coverId == null || coverId <= 0) return '';
    return 'https://covers.openlibrary.org/b/id/$coverId-$size.jpg';
  }

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
      publisher: data['publisher'] ?? '',
      isbn: data['isbn'] ?? '',
      pageCount: (data['pageCount'] as num?)?.toInt() ?? 0,
      subjects: subjects,
      status: data['status'] ?? 'to-read',
      userName: data['userName'] ?? '',
      addedAt: _parseDateTime(data['addedAt']),
      readSourceUrl:
          data['readSourceUrl'] ??
          deriveReadSourceUrl(iaId: iaId, workKey: workKey),
      readSourceLabel:
          data['readSourceLabel'] ?? deriveReadSourceLabel(iaId: iaId),
    );
  }

  static String deriveReadSourceUrl({
    required String iaId,
    required String workKey,
  }) {
    if (iaId.isNotEmpty && iaId.startsWith('pg') && iaId.length > 2) {
      final id = iaId.substring(2);
      return 'https://www.gutenberg.org/cache/epub/$id/pg$id.txt';
    }
    if (iaId.isNotEmpty) {
      return 'https://archive.org/details/$iaId';
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
      'publisher': publisher,
      'isbn': isbn,
      'pageCount': pageCount,
      'subjects': subjects,
      'status': status,
      'userName': userName,
      'addedAt': Timestamp.fromDate(addedAt),
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
    String? publisher,
    String? isbn,
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
      publisher: publisher ?? this.publisher,
      isbn: isbn ?? this.isbn,
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
