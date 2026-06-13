import 'package:cloud_firestore/cloud_firestore.dart';

enum HexGLTrack {
  cityscape;

  String get id {
    switch (this) {
      case HexGLTrack.cityscape:
        return 'cityscape';
    }
  }

  String get displayName {
    switch (this) {
      case HexGLTrack.cityscape:
        return 'Cityscape';
    }
  }

  String get description {
    switch (this) {
      case HexGLTrack.cityscape:
        return 'Neon canyons and twisting loops through a futuristic skyline';
    }
  }

  static HexGLTrack fromId(String id) {
    return HexGLTrack.values.firstWhere(
      (t) => t.id == id,
      orElse: () => HexGLTrack.cityscape,
    );
  }
}

enum HexGLResultStatus {
  finished,
  destroyed,
  replay,
  abandoned;

  static HexGLResultStatus fromLabel(String? label) {
    switch (label) {
      case 'finished':
        return HexGLResultStatus.finished;
      case 'destroyed':
        return HexGLResultStatus.destroyed;
      case 'replay':
        return HexGLResultStatus.replay;
      default:
        return HexGLResultStatus.abandoned;
    }
  }
}

class HexGLRaceResult {
  final String userId;
  final int finishTimeMs;
  final List<int> lapTimesMs;
  final HexGLResultStatus status;
  final String trackId;
  final List<List<double>>? replay;
  final DateTime createdAt;

  const HexGLRaceResult({
    required this.userId,
    required this.finishTimeMs,
    required this.lapTimesMs,
    required this.status,
    required this.trackId,
    required this.replay,
    required this.createdAt,
  });

  bool get isFinished => status == HexGLResultStatus.finished;
  bool get isReplay => status == HexGLResultStatus.replay;

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'finishTimeMs': finishTimeMs,
      'lapTimesMs': lapTimesMs,
      'status': status.name,
      'trackId': trackId,
      'replay': replay,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory HexGLRaceResult.fromMap(Map<String, dynamic> map) {
    final lapTimes = (map['lapTimesMs'] as List?)
            ?.map((e) => (e as num).toInt())
            .toList() ??
        <int>[];
    final replayRaw = map['replay'] as List?;
    final replay = replayRaw?.map<List<double>>((row) => (row as List)
        .map<double>((v) => (v as num).toDouble())
        .toList()).toList();
    return HexGLRaceResult(
      userId: map['userId'] ?? '',
      finishTimeMs: (map['finishTimeMs'] as num?)?.toInt() ?? 0,
      lapTimesMs: lapTimes,
      status: HexGLResultStatus.values.firstWhere(
        (s) => s.name == (map['status'] ?? 'abandoned'),
        orElse: () => HexGLResultStatus.abandoned,
      ),
      trackId: map['trackId'] ?? HexGLTrack.cityscape.id,
      replay: replay,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
