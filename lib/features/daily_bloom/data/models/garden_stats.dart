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
    final data = doc.data() as Map<String, dynamic>;
    return GardenStats(
      currentStage: data['currentStage'] ?? 0,
      lastVisit: (data['lastVisit'] as Timestamp).toDate(),
      streakCount: data['streakCount'] ?? 0,
      totalInteractions: data['totalInteractions'] ?? 0,
      plantType: data['plantType'] ?? 'lily',
    );
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
