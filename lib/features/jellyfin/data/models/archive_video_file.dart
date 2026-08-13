/// A downloadable video file inside an Internet Archive item.
class ArchiveVideoFile {
  final String identifier;
  final String name;
  final String format;
  final int sizeBytes;
  final double? lengthSeconds;
  final int? width;
  final int? height;

  const ArchiveVideoFile({
    required this.identifier,
    required this.name,
    required this.format,
    required this.sizeBytes,
    this.lengthSeconds,
    this.width,
    this.height,
  });

  String get downloadUrl =>
      'https://archive.org/download/$identifier/${Uri.encodeComponent(name)}';

  String get extension {
    final dot = name.lastIndexOf('.');
    if (dot < 0 || dot == name.length - 1) return '';
    return name.substring(dot + 1).toLowerCase();
  }

  String get humanSize {
    if (sizeBytes <= 0) return 'Unknown size';
    final gb = sizeBytes / (1024 * 1024 * 1024);
    if (gb >= 1) return '${gb.toStringAsFixed(1)} GB';
    final mb = sizeBytes / (1024 * 1024);
    if (mb >= 1) return '${mb.round()} MB';
    return '${(sizeBytes / 1024).round()} KB';
  }

  String get humanLength {
    final seconds = lengthSeconds;
    if (seconds == null || seconds <= 0) return '';
    final total = seconds.round();
    final hours = total ~/ 3600;
    final minutes = (total % 3600) ~/ 60;
    if (hours > 0) return '${hours}h ${minutes}m';
    return '${minutes}m';
  }

  bool get isPlayableContainer {
    const video = {'mp4', 'webm', 'mkv', 'm4v', 'avi', 'mov', 'ogv'};
    return video.contains(extension);
  }
}
