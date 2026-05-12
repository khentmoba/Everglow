import 'package:cloud_firestore/cloud_firestore.dart';

class GardenStats {
  final int currentStage;
  final DateTime lastVisit;
  final int streakCount;
  final int totalInteractions;

  GardenStats({
    required this.currentStage,
    required this.lastVisit,
    required this.streakCount,
    required this.totalInteractions,
  });

  factory GardenStats.initial() {
    return GardenStats(
      currentStage: 0,
      lastVisit: DateTime.now(),
      streakCount: 0,
      totalInteractions: 0,
    );
  }

  factory GardenStats.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return GardenStats(
      currentStage: data['currentStage'] ?? 0,
      lastVisit: (data['lastVisit'] as Timestamp).toDate(),
      streakCount: data['streakCount'] ?? 0,
      totalInteractions: data['totalInteractions'] ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'currentStage': currentStage,
      'lastVisit': Timestamp.fromDate(lastVisit),
      'streakCount': streakCount,
      'totalInteractions': totalInteractions,
    };
  }

  GardenStats copyWith({
    int? currentStage,
    DateTime? lastVisit,
    int? streakCount,
    int? totalInteractions,
  }) {
    return GardenStats(
      currentStage: currentStage ?? this.currentStage,
      lastVisit: lastVisit ?? this.lastVisit,
      streakCount: streakCount ?? this.streakCount,
      totalInteractions: totalInteractions ?? this.totalInteractions,
    );
  }
}
