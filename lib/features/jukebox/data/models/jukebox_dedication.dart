import 'package:cloud_firestore/cloud_firestore.dart';

/// A loved-track dedication from one partner to the other.
class JukeboxDedication {
  final String id;
  final String fromUsername;
  final String toUsername;
  final String trackName;
  final String artistName;
  final String? imageUrl;
  final String? message;
  final DateTime createdAt;

  const JukeboxDedication({
    required this.id,
    required this.fromUsername,
    required this.toUsername,
    required this.trackName,
    required this.artistName,
    this.imageUrl,
    this.message,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'fromUsername': fromUsername,
    'toUsername': toUsername,
    'trackName': trackName,
    'artistName': artistName,
    'imageUrl': imageUrl,
    'message': message,
    'createdAt': Timestamp.fromDate(createdAt),
  };

  factory JukeboxDedication.fromMap(String id, Map<String, dynamic> map) {
    final ts = map['createdAt'];
    DateTime created;
    if (ts is Timestamp) {
      created = ts.toDate();
    } else if (ts is String) {
      created = DateTime.tryParse(ts) ?? DateTime.now();
    } else {
      created = DateTime.now();
    }
    return JukeboxDedication(
      id: id,
      fromUsername: map['fromUsername'] as String? ?? '',
      toUsername: map['toUsername'] as String? ?? '',
      trackName: map['trackName'] as String? ?? '',
      artistName: map['artistName'] as String? ?? '',
      imageUrl: map['imageUrl'] as String?,
      message: map['message'] as String?,
      createdAt: created,
    );
  }
}
