class TrackMetadata {
  final String? artworkUrl;
  final String? albumName;

  const TrackMetadata({
    this.artworkUrl,
    this.albumName,
  });

  TrackMetadata copyWith({
    String? artworkUrl,
    String? albumName,
  }) {
    return TrackMetadata(
      artworkUrl: artworkUrl ?? this.artworkUrl,
      albumName: albumName ?? this.albumName,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TrackMetadata &&
          runtimeType == other.runtimeType &&
          artworkUrl == other.artworkUrl &&
          albumName == other.albumName;

  @override
  int get hashCode => Object.hash(artworkUrl, albumName);
}
