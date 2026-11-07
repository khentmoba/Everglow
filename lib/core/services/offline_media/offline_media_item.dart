import 'package:flutter/foundation.dart';

/// Supported offline media surface types.
enum OfflineMediaType {
  movie,
  tv,
  anime,
  manga;

  static OfflineMediaType fromString(String value) {
    return OfflineMediaType.values.firstWhere(
      (e) => e.name == value.toLowerCase(),
      orElse: () => OfflineMediaType.movie,
    );
  }
}

/// Download lifecycle statuses for offline items.
enum OfflineDownloadStatus {
  queued,
  downloading,
  completed,
  paused,
  failed;

  static OfflineDownloadStatus fromString(String value) {
    return OfflineDownloadStatus.values.firstWhere(
      (e) => e.name == value.toLowerCase(),
      orElse: () => OfflineDownloadStatus.completed,
    );
  }
}

/// One downloadable offline movie, TV episode, anime episode, or manga chapter.
@immutable
class OfflineMediaItem {
  final String id;
  final OfflineMediaType type;
  final String mediaId;
  final String title;
  final String subtitle;
  final int? season;
  final int? episode;
  final String? chapterId;
  final String coverUrl;
  final String? sourceUrl;
  final OfflineDownloadStatus status;
  final double progress;
  final int totalBytes;
  final int downloadedBytes;
  final DateTime downloadedAt;
  final int? durationSeconds;
  final int? lastPositionSeconds;
  final List<String> pageUrls;
  final String? blobKey;

  const OfflineMediaItem({
    required this.id,
    required this.type,
    required this.mediaId,
    required this.title,
    this.subtitle = '',
    this.season,
    this.episode,
    this.chapterId,
    this.coverUrl = '',
    this.sourceUrl,
    this.status = OfflineDownloadStatus.completed,
    this.progress = 1.0,
    this.totalBytes = 0,
    this.downloadedBytes = 0,
    required this.downloadedAt,
    this.durationSeconds,
    this.lastPositionSeconds,
    this.pageUrls = const [],
    this.blobKey,
  });

  bool get isCinema =>
      type == OfflineMediaType.movie || type == OfflineMediaType.tv;
  bool get isAnime => type == OfflineMediaType.anime;
  bool get isManga => type == OfflineMediaType.manga;
  bool get isEpisode =>
      type == OfflineMediaType.tv || type == OfflineMediaType.anime;
  bool get isCompleted => status == OfflineDownloadStatus.completed;
  bool get isDownloading => status == OfflineDownloadStatus.downloading;

  String get formattedSize {
    final bytes = totalBytes > 0 ? totalBytes : downloadedBytes;
    if (bytes <= 0) return '0 MB';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  String get formattedDuration {
    final sec = durationSeconds ?? 0;
    if (sec <= 0) return '';
    final h = sec ~/ 3600;
    final m = (sec % 3600) ~/ 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  String get formattedProgress => '${(progress.clamp(0.0, 1.0) * 100).toInt()}%';

  OfflineMediaItem copyWith({
    String? id,
    OfflineMediaType? type,
    String? mediaId,
    String? title,
    String? subtitle,
    int? season,
    int? episode,
    String? chapterId,
    String? coverUrl,
    String? sourceUrl,
    OfflineDownloadStatus? status,
    double? progress,
    int? totalBytes,
    int? downloadedBytes,
    DateTime? downloadedAt,
    int? durationSeconds,
    int? lastPositionSeconds,
    List<String>? pageUrls,
    String? blobKey,
  }) {
    return OfflineMediaItem(
      id: id ?? this.id,
      type: type ?? this.type,
      mediaId: mediaId ?? this.mediaId,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      season: season ?? this.season,
      episode: episode ?? this.episode,
      chapterId: chapterId ?? this.chapterId,
      coverUrl: coverUrl ?? this.coverUrl,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      totalBytes: totalBytes ?? this.totalBytes,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      downloadedAt: downloadedAt ?? this.downloadedAt,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      lastPositionSeconds: lastPositionSeconds ?? this.lastPositionSeconds,
      pageUrls: pageUrls ?? this.pageUrls,
      blobKey: blobKey ?? this.blobKey,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'mediaId': mediaId,
      'title': title,
      'subtitle': subtitle,
      'season': season,
      'episode': episode,
      'chapterId': chapterId,
      'coverUrl': coverUrl,
      'sourceUrl': sourceUrl,
      'status': status.name,
      'progress': progress,
      'totalBytes': totalBytes,
      'downloadedBytes': downloadedBytes,
      'downloadedAt': downloadedAt.toIso8601String(),
      'durationSeconds': durationSeconds,
      'lastPositionSeconds': lastPositionSeconds,
      'pageUrls': pageUrls,
      'blobKey': blobKey,
    };
  }

  factory OfflineMediaItem.fromJson(Map<String, dynamic> json) {
    return OfflineMediaItem(
      id: json['id'] as String? ?? '',
      type: OfflineMediaType.fromString(json['type'] as String? ?? 'movie'),
      mediaId: json['mediaId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      season: json['season'] as int?,
      episode: json['episode'] as int?,
      chapterId: json['chapterId'] as String?,
      coverUrl: json['coverUrl'] as String? ?? '',
      sourceUrl: json['sourceUrl'] as String?,
      status: OfflineDownloadStatus.fromString(
        json['status'] as String? ?? 'completed',
      ),
      progress: (json['progress'] as num?)?.toDouble() ?? 1.0,
      totalBytes: json['totalBytes'] as int? ?? 0,
      downloadedBytes: json['downloadedBytes'] as int? ?? 0,
      downloadedAt: json['downloadedAt'] != null
          ? DateTime.tryParse(json['downloadedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      durationSeconds: json['durationSeconds'] as int?,
      lastPositionSeconds: json['lastPositionSeconds'] as int?,
      pageUrls: (json['pageUrls'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
      blobKey: json['blobKey'] as String?,
    );
  }
}
