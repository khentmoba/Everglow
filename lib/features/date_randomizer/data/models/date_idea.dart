class DateIdea {
  final String id;
  final String title;

  DateIdea({
    required this.id,
    required this.title,
  });

  factory DateIdea.fromFirestore(Map<String, dynamic> data, String documentId) {
    return DateIdea(
      id: documentId,
      title: data['title'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
    };
  }
}
