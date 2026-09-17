import 'package:cloud_firestore/cloud_firestore.dart';

/// A mini-game Motchi built, saved from chat into Motchi's Minis.
///
/// The HTML is the same self-contained file the preview runs (scripts run
/// sandboxed, no network identity). Tolerant parsing: a half-written doc
/// renders as an untitled mini instead of crashing the shelf.
class MiniGame {
  final String id;
  final String title;
  final String html;
  final String createdBy;
  final DateTime? createdAt;

  const MiniGame({
    required this.id,
    required this.title,
    required this.html,
    this.createdBy = '',
    this.createdAt,
  });

  factory MiniGame.fromFirestore(Map<String, dynamic> data, String id) {
    return MiniGame(
      id: id,
      title: _asString(data['title']),
      html: _asString(data['html']),
      createdBy: _asString(data['createdBy']),
      createdAt: _parseTimestamp(data['createdAt']),
    );
  }

  static String _asString(dynamic value) =>
      value is String ? value : '';

  static DateTime? _parseTimestamp(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (_) {
        return null;
      }
    }
    return null;
  }
}
