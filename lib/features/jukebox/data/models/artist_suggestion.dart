import 'lastfm_image_utils.dart';

/// One row from `artist.search`: a pickable artist name plus the bits the
/// autocomplete dropdown shows (listeners + tiny cover).
class ArtistSuggestion {
  final String name;
  final int listeners;
  final String? imageUrl;
  final String url;
  final String? mbid;

  const ArtistSuggestion({
    required this.name,
    required this.listeners,
    this.imageUrl,
    required this.url,
    this.mbid,
  });

  ArtistSuggestion copyWith({
    String? name,
    int? listeners,
    String? imageUrl,
    String? url,
    String? mbid,
  }) {
    return ArtistSuggestion(
      name: name ?? this.name,
      listeners: listeners ?? this.listeners,
      imageUrl: imageUrl ?? this.imageUrl,
      url: url ?? this.url,
      mbid: mbid ?? this.mbid,
    );
  }

  factory ArtistSuggestion.fromJson(Map<String, dynamic> json) {
    final name = (json['name'] as String? ?? '').trim();
    final listeners =
        int.tryParse(json['listeners']?.toString() ?? '') ?? 0;
    final imgUrl = pickLastfmImageUrl(json['image'] as List<dynamic>?);
    final url = json['url'] as String? ?? '';
    final mbid = json['mbid'] as String?;
    return ArtistSuggestion(
      name: name,
      listeners: listeners,
      imageUrl: imgUrl,
      url: url,
      mbid: mbid?.isNotEmpty == true ? mbid : null,
    );
  }
}
