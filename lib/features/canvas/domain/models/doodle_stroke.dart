import 'package:cloud_firestore/cloud_firestore.dart';

class DoodleStroke {
  /// Legacy strokes were saved without their source canvas dimensions.
  static const legacyCanvasAspectRatio = 2.0;

  final String id;
  final List<Map<String, double>> points;
  final String color;
  final double strokeWidth;
  final double canvasAspectRatio;
  final DateTime? createdAt;
  final String userId;

  /// Optional text content. When non-null, this stroke is a text annotation
  /// positioned at [points.first].
  final String? text;

  DoodleStroke({
    required this.id,
    required this.points,
    required this.color,
    required this.strokeWidth,
    this.canvasAspectRatio = legacyCanvasAspectRatio,
    this.createdAt,
    required this.userId,
    this.text,
  });

  /// Whether this stroke is a text annotation rather than a freehand drawing.
  bool get isTextAnnotation => text != null && text!.isNotEmpty;

  factory DoodleStroke.fromFirestore(DocumentSnapshot doc) =>
      DoodleStroke.fromMap(
        doc.data() as Map<String, dynamic>? ?? const {},
        doc.id,
      );

  factory DoodleStroke.fromMap(Map<String, dynamic> data, String id) {
    return DoodleStroke(
      id: id,
      points: _parsePoints(data['points']),
      color: _toStr(data['color'], '#FFC0CB'),
      strokeWidth: _toDouble(data['strokeWidth'], 3.0),
      canvasAspectRatio: _toDouble(
        data['canvasAspectRatio'],
        legacyCanvasAspectRatio,
      ),
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
      userId: _toStr(data['userId'], ''),
      text: data['text'] is String ? data['text'] as String : null,
    );
  }

  static String _toStr(dynamic value, String fallback) =>
      value is String ? value : fallback;

  static double _toDouble(dynamic value, double fallback) =>
      value is num ? value.toDouble() : fallback;

  /// Parses stroke points without throwing: one malformed point or
  /// stroke document must never brick the whole shared canvas for
  /// both partners. Bad entries are skipped, bad shapes become empty.
  static List<Map<String, double>> _parsePoints(dynamic raw) {
    if (raw is! List) return const [];
    final points = <Map<String, double>>[];
    for (final p in raw) {
      if (p is Map) {
        final x = p['x'];
        final y = p['y'];
        if (x is num && y is num) {
          points.add({'x': x.toDouble(), 'y': y.toDouble()});
        }
      }
    }
    return points;
  }

  Map<String, dynamic> toMap() {
    return {
      'points': points,
      'color': color,
      'strokeWidth': strokeWidth,
      'canvasAspectRatio': canvasAspectRatio,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'userId': userId,
      if (text != null) 'text': text,
    };
  }

  DoodleStroke copyWith({
    String? id,
    List<Map<String, double>>? points,
    String? color,
    double? strokeWidth,
    double? canvasAspectRatio,
    DateTime? createdAt,
    String? userId,
    String? text,
  }) {
    return DoodleStroke(
      id: id ?? this.id,
      points: points ?? this.points,
      color: color ?? this.color,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      canvasAspectRatio: canvasAspectRatio ?? this.canvasAspectRatio,
      createdAt: createdAt ?? this.createdAt,
      userId: userId ?? this.userId,
      text: text ?? this.text,
    );
  }
}
