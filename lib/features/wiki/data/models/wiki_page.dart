import 'package:cloud_firestore/cloud_firestore.dart';

enum WikiShelfIcon { book, heart, map, star, music, film, trip, other }

class WikiShelf {
  final String id;
  final String title;
  final String description;
  final String icon; // emoji
  final String createdBy;
  final DateTime createdAt;
  final int order;

  const WikiShelf({
    required this.id,
    required this.title,
    this.description = '',
    this.icon = '📚',
    required this.createdBy,
    required this.createdAt,
    this.order = 0,
  });

  factory WikiShelf.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return WikiShelf(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      icon: data['icon'] ?? '📚',
      createdBy: data['createdBy'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      order: data['order'] ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'title': title,
    'description': description,
    'icon': icon,
    'createdBy': createdBy,
    'createdAt': Timestamp.fromDate(createdAt),
    'order': order,
  };
}

class WikiBook {
  final String id;
  final String shelfId;
  final String title;
  final String description;
  final String coverColor;
  final String createdBy;
  final DateTime createdAt;
  final int order;

  const WikiBook({
    required this.id,
    required this.shelfId,
    required this.title,
    this.description = '',
    this.coverColor = '#8E44AD',
    required this.createdBy,
    required this.createdAt,
    this.order = 0,
  });

  factory WikiBook.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return WikiBook(
      id: doc.id,
      shelfId: data['shelfId'] ?? '',
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      coverColor: data['coverColor'] ?? '#8E44AD',
      createdBy: data['createdBy'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      order: data['order'] ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'shelfId': shelfId,
    'title': title,
    'description': description,
    'coverColor': coverColor,
    'createdBy': createdBy,
    'createdAt': Timestamp.fromDate(createdAt),
    'order': order,
  };
}

class WikiPage {
  final String id;
  final String bookId;
  final String title;
  final String markdown;
  final String author;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> tags;
  final int wordCount;
  final bool isPinned;

  const WikiPage({
    required this.id,
    required this.bookId,
    required this.title,
    this.markdown = '',
    required this.author,
    required this.createdAt,
    required this.updatedAt,
    this.tags = const [],
    this.wordCount = 0,
    this.isPinned = false,
  });

  factory WikiPage.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final md = data['markdown'] ?? data['content'] ?? '';
    return WikiPage(
      id: doc.id,
      bookId: data['bookId'] ?? '',
      title: data['title'] ?? '',
      markdown: md,
      author: data['author'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      tags: (data['tags'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      wordCount:
          data['wordCount'] ??
          md.toString().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length,
      isPinned: data['isPinned'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'bookId': bookId,
    'title': title,
    'markdown': markdown,
    'author': author,
    'createdAt': Timestamp.fromDate(createdAt),
    'updatedAt': Timestamp.fromDate(updatedAt),
    'tags': tags,
    'wordCount': wordCount,
    'isPinned': isPinned,
    'searchKey':
        '${title.toLowerCase()} ${markdown.toString().substring(0, markdown.length > 500 ? 500 : markdown.length).toLowerCase()}',
  };
}
