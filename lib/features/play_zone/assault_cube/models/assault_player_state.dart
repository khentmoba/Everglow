import 'package:cloud_firestore/cloud_firestore.dart';

class AssaultPlayerState {
  final String userId;
  final double x;
  final double y;
  final double angle;
  final int hp;
  final int kills;
  final bool alive;
  final DateTime lastUpdate;

  const AssaultPlayerState({
    required this.userId,
    required this.x,
    required this.y,
    required this.angle,
    required this.hp,
    required this.kills,
    required this.alive,
    required this.lastUpdate,
  });

  factory AssaultPlayerState.initial(String userId, double x, double y) {
    return AssaultPlayerState(
      userId: userId,
      x: x,
      y: y,
      angle: 0.0,
      hp: 100,
      kills: 0,
      alive: true,
      lastUpdate: DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'x': x,
      'y': y,
      'angle': angle,
      'hp': hp,
      'kills': kills,
      'alive': alive,
      'lastUpdate': FieldValue.serverTimestamp(),
    };
  }

  factory AssaultPlayerState.fromMap(Map<String, dynamic> map) {
    return AssaultPlayerState(
      userId: map['userId'] ?? '',
      x: (map['x'] as num?)?.toDouble() ?? 0.0,
      y: (map['y'] as num?)?.toDouble() ?? 0.0,
      angle: (map['angle'] as num?)?.toDouble() ?? 0.0,
      hp: (map['hp'] as num?)?.toInt() ?? 100,
      kills: (map['kills'] as num?)?.toInt() ?? 0,
      alive: map['alive'] ?? true,
      lastUpdate: (map['lastUpdate'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  factory AssaultPlayerState.fromFirestore(DocumentSnapshot doc) {
    return AssaultPlayerState.fromMap(doc.data() as Map<String, dynamic>);
  }

  AssaultPlayerState copyWith({
    double? x,
    double? y,
    double? angle,
    int? hp,
    int? kills,
    bool? alive,
    DateTime? lastUpdate,
  }) {
    return AssaultPlayerState(
      userId: userId,
      x: x ?? this.x,
      y: y ?? this.y,
      angle: angle ?? this.angle,
      hp: hp ?? this.hp,
      kills: kills ?? this.kills,
      alive: alive ?? this.alive,
      lastUpdate: lastUpdate ?? this.lastUpdate,
    );
  }
}

class AssaultShot {
  final String id;
  final String shooterId;
  final double originX;
  final double originY;
  final double angle;
  final double speed;
  final double damage;
  final double range;
  final DateTime createdAt;

  const AssaultShot({
    required this.id,
    required this.shooterId,
    required this.originX,
    required this.originY,
    required this.angle,
    required this.speed,
    required this.damage,
    required this.range,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'shooterId': shooterId,
      'originX': originX,
      'originY': originY,
      'angle': angle,
      'speed': speed,
      'damage': damage,
      'range': range,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory AssaultShot.fromMap(Map<String, dynamic> map) {
    return AssaultShot(
      id: map['id'] ?? '',
      shooterId: map['shooterId'] ?? '',
      originX: (map['originX'] as num?)?.toDouble() ?? 0.0,
      originY: (map['originY'] as num?)?.toDouble() ?? 0.0,
      angle: (map['angle'] as num?)?.toDouble() ?? 0.0,
      speed: (map['speed'] as num?)?.toDouble() ?? 0.0,
      damage: (map['damage'] as num?)?.toDouble() ?? 0.0,
      range: (map['range'] as num?)?.toDouble() ?? 0.0,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  factory AssaultShot.fromFirestore(DocumentSnapshot doc) {
    return AssaultShot.fromMap(doc.data() as Map<String, dynamic>);
  }
}
