import 'lastfm_image_utils.dart';

/// Entry from `user.getTopArtists`.
class TopArtist {
  final int rank;
  final String name;
  final int playCount;
  final String? imageUrl;
  final String url;
  final String? mbid;

  const TopArtist({
    required this.rank,
    required this.name,
    required this.playCount,
    this.imageUrl,
    required this.url,
    this.mbid,
  });

  factory TopArtist.fromJson(Map<String, dynamic> json) {
    final name = json['name'] as String? ?? 'Unknown Artist';
    final images = json['image'] as List<dynamic>?;
    String? imgUrl;
    if (images != null && images.isNotEmpty) {
      dynamic sel = images.last;
      for (final img in images) {
        if (img is Map && img['size'] == 'extralarge') {
          sel = img;
          break;
        }
      }
      if (sel is Map) imgUrl = sel['#text'] as String?;
    }
    final attr = json['@attr'];
    final rank =
        int.tryParse(attr is Map ? (attr['rank']?.toString() ?? '') : '') ?? 0;
    final playCount = int.tryParse(json['playcount']?.toString() ?? '') ?? 0;
    final url = json['url'] as String? ?? '';
    final mbid = json['mbid'] as String?;
    return TopArtist(
      rank: rank,
      name: name,
      playCount: playCount,
      imageUrl: cleanLastfmImageUrl(imgUrl),
      url: url,
      mbid: mbid?.isNotEmpty == true ? mbid : null,
    );
  }
}
