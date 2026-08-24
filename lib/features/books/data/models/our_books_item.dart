import 'package:cloud_firestore/cloud_firestore.dart';
import './book_item.dart';

/// A single entry in the shared "Our Books" list, visible to Khent
/// and Clair only. Mirrors the cinema's `OurCinemaItem` shape.
class OurBooksItem {
  final String id;
  final String workKey;
  final String editionKey;
  final String iaId;
  final String title;
  final String author;
  final String coverUrl;
  final String year;
  final List<String> subjects;

  /// Which partner added the item. Always one of 'khentsgdz' or
  /// 'clairjassen'.
  final String addedBy;

  final DateTime addedAt;

  /// `null` means Khent has not read it yet.
  final DateTime? khentReadAt;

  /// `null` means Clair has not read it yet.
  final DateTime? clairReadAt;

  const OurBooksItem({
    required this.id,
    required this.workKey,
    this.editionKey = '',
    this.iaId = '',
    required this.title,
    this.author = '',
    this.coverUrl = '',
    this.year = '',
    this.subjects = const [],
    required this.addedBy,
    required this.addedAt,
    this.khentReadAt,
    this.clairReadAt,
  });

  String get status {
    final k = khentReadAt != null;
    final c = clairReadAt != null;
    if (k && c) return 'read-both';
    if (k) return 'read-khent';
    if (c) return 'read-clair';
    return 'to-read';
  }

  bool get isRead => khentReadAt != null || clairReadAt != null;
  bool get isReadByKhent => khentReadAt != null;
  bool get isReadByClair => clairReadAt != null;

  /// Mirrors [BookItem.readSourceLabel]. Computed lazily from the
  /// `iaId` / `workKey` so the couple list always knows which
  /// provider powers the read source even if the model was
  /// reconstructed from Firestore (where this field is not
  /// persisted).
  String get readSourceLabel {
    if (iaId.isNotEmpty) return 'Internet Archive';
    if (workKey.isNotEmpty) return 'Open Library';
    return '';
  }

  String get statusLabel {
    switch (status) {
      case 'read-both':
        return 'Read by Both';
      case 'read-khent':
        return 'Read by Khent';
      case 'read-clair':
        return 'Read by Clair';
      default:
        return 'To Read Together';
    }
  }

  BookItem toBookItem() {
    return BookItem(
      id: id,
      workKey: workKey,
      editionKey: editionKey,
      iaId: iaId,
      title: title,
      author: author,
      coverUrl: coverUrl,
      year: year,
      subjects: subjects,
      status: status,
      userName: addedBy,
      addedAt: addedAt,
    );
  }

  factory OurBooksItem.fromFirestore(
    Map<String, dynamic> data,
    String documentId,
  ) {
    final subjectsRaw = data['subjects'];
    final subjects = subjectsRaw is List
        ? subjectsRaw.map((e) => e.toString()).toList()
        : const <String>[];
    return OurBooksItem(
      id: documentId,
      workKey: data['workKey'] ?? '',
      editionKey: data['editionKey'] ?? '',
      iaId: data['iaId'] ?? '',
      title: data['title'] ?? '',
      author: data['author'] ?? '',
      coverUrl: data['coverUrl'] ?? '',
      year: data['year'] ?? '',
      subjects: subjects,
      addedBy: data['addedBy'] ?? '',
      addedAt: _parseDateTime(data['addedAt']),
      khentReadAt: _parseNullableDateTime(data['khentReadAt']),
      clairReadAt: _parseNullableDateTime(data['clairReadAt']),
    );
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
      'subjects': subjects,
      'addedBy': addedBy,
      'addedAt': Timestamp.fromDate(addedAt),
      'khentReadAt': khentReadAt == null
          ? null
          : Timestamp.fromDate(khentReadAt!),
      'clairReadAt': clairReadAt == null
          ? null
          : Timestamp.fromDate(clairReadAt!),
    };
  }

  OurBooksItem copyWith({
    String? id,
    String? workKey,
    String? editionKey,
    String? iaId,
    String? title,
    String? author,
    String? coverUrl,
    String? year,
    List<String>? subjects,
    String? addedBy,
    DateTime? addedAt,
    DateTime? khentReadAt,
    DateTime? clairReadAt,
    bool clearKhentRead = false,
    bool clearClairRead = false,
  }) {
    return OurBooksItem(
      id: id ?? this.id,
      workKey: workKey ?? this.workKey,
      editionKey: editionKey ?? this.editionKey,
      iaId: iaId ?? this.iaId,
      title: title ?? this.title,
      author: author ?? this.author,
      coverUrl: coverUrl ?? this.coverUrl,
      year: year ?? this.year,
      subjects: subjects ?? this.subjects,
      addedBy: addedBy ?? this.addedBy,
      addedAt: addedAt ?? this.addedAt,
      khentReadAt: clearKhentRead ? null : (khentReadAt ?? this.khentReadAt),
      clairReadAt: clearClairRead ? null : (clairReadAt ?? this.clairReadAt),
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

  static DateTime? _parseNullableDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (_) {
        return null;
      }
    }
    return null;
  }
}
