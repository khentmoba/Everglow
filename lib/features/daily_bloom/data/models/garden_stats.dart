import 'package:cloud_firestore/cloud_firestore.dart';

class GardenStats {
  final int currentStage;
  final DateTime lastVisit;
  final int streakCount;
  final int totalInteractions;
  final String plantType;

  GardenStats({
    required this.currentStage,
    required this.lastVisit,
    required this.streakCount,
    required this.totalInteractions,
    this.plantType = 'lily',
  });

  factory GardenStats.initial() {
    return GardenStats(
      currentStage: 0,
      lastVisit: DateTime.now(),
      streakCount: 0,
      totalInteractions: 0,
      plantType: 'lily',
    );
  }

  factory GardenStats.fromFirestore(DocumentSnapshot doc) {
    return GardenStats.fromMap(doc.data() as Map<String, dynamic>);
  }

  factory GardenStats.fromMap(Map<String, dynamic> data) {
    return GardenStats(
      currentStage: (data['currentStage'] as num?)?.toInt() ?? 0,
      lastVisit: _parseTimestamp(data['lastVisit']),
      streakCount: (data['streakCount'] as num?)?.toInt() ?? 0,
      totalInteractions: (data['totalInteractions'] as num?)?.toInt() ?? 0,
      plantType: data['plantType'] as String? ?? 'lily',
    );
  }

  static DateTime _parseTimestamp(dynamic value) {
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

  Map<String, dynamic> toFirestore() {
    return {
      'currentStage': currentStage,
      'lastVisit': Timestamp.fromDate(lastVisit),
      'streakCount': streakCount,
      'totalInteractions': totalInteractions,
      'plantType': plantType,
    };
  }

  GardenStats copyWith({
    int? currentStage,
    DateTime? lastVisit,
    int? streakCount,
    int? totalInteractions,
    String? plantType,
  }) {
    return GardenStats(
      currentStage: currentStage ?? this.currentStage,
      lastVisit: lastVisit ?? this.lastVisit,
      streakCount: streakCount ?? this.streakCount,
      totalInteractions: totalInteractions ?? this.totalInteractions,
      plantType: plantType ?? this.plantType,
    );
  }
}
