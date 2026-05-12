import 'package:cloud_firestore/cloud_firestore.dart';

class DoodleStroke {
  final String id;
  final List<Map<String, double>> points;
  final String color;
  final double strokeWidth;
  final DateTime? createdAt;
  final String userId;

  DoodleStroke({
    required this.id,
    required this.points,
    required this.color,
    required this.strokeWidth,
    this.createdAt,
    required this.userId,
  });

  factory DoodleStroke.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DoodleStroke(
      id: doc.id,
      points: (data['points'] as List).map((p) => {
        'x': (p['x'] as num).toDouble(),
        'y': (p['y'] as num).toDouble(),
      }).toList(),
      color: data['color'] ?? '#FFC0CB',
      strokeWidth: (data['strokeWidth'] as num?)?.toDouble() ?? 3.0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      userId: data['userId'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'points': points,
      'color': color,
      'strokeWidth': strokeWidth,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'userId': userId,
    };
  }

  DoodleStroke copyWith({
    String? id,
    List<Map<String, double>>? points,
    String? color,
    double? strokeWidth,
    DateTime? createdAt,
    String? userId,
  }) {
    return DoodleStroke(
      id: id ?? this.id,
      points: points ?? this.points,
      color: color ?? this.color,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      createdAt: createdAt ?? this.createdAt,
      userId: userId ?? this.userId,
    );
  }
}
