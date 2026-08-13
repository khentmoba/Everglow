/// A movie result from the Internet Archive open-media catalog.
class ArchiveMovie {
  final String identifier;
  final String title;
  final String? year;
  final String? description;

  const ArchiveMovie({
    required this.identifier,
    required this.title,
    this.year,
    this.description,
  });

  String get thumbnailUrl => 'https://archive.org/services/img/$identifier';

  factory ArchiveMovie.fromJson(Map<String, dynamic> json) {
    return ArchiveMovie(
      identifier: json['identifier'] as String? ?? '',
      title: json['title'] as String? ?? '',
      year: json['year']?.toString(),
      description: json['description'] as String?,
    );
  }
}
