import 'package:cloud_firestore/cloud_firestore.dart';

enum TripStatus { planning, upcoming, active, completed }

class Trip {
  final String id;
  final String title;
  final String description;
  final String coverUrl;
  final DateTime startDate;
  final DateTime endDate;
  final TripStatus status;
  final String createdBy;
  final DateTime createdAt;
  final double budgetEstimate;
  final String currency;
  final List<String> memberIds;

  const Trip({
    required this.id,
    required this.title,
    this.description = '',
    this.coverUrl = '',
    required this.startDate,
    required this.endDate,
    this.status = TripStatus.planning,
    required this.createdBy,
    required this.createdAt,
    this.budgetEstimate = 0,
    this.currency = 'PHP',
    this.memberIds = const ['khentsgdz', 'clairjassen'],
  });

  static TripStatus _parseStatus(dynamic v) {
    if (v is String) for (final s in TripStatus.values) if (s.name == v) return s;
    return TripStatus.planning;
  }

  factory Trip.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Trip(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      coverUrl: data['coverUrl'] ?? '',
      startDate: (data['startDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endDate: (data['endDate'] as Timestamp?)?.toDate() ?? DateTime.now().add(const Duration(days: 3)),
      status: _parseStatus(data['status']),
      createdBy: data['createdBy'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      budgetEstimate: (data['budgetEstimate'] ?? 0).toDouble(),
      currency: data['currency'] ?? 'PHP',
      memberIds: (data['memberIds'] as List<dynamic>? ?? ['khentsgdz', 'clairjassen']).map((e) => e.toString()).toList(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'title': title,
        'description': description,
        'coverUrl': coverUrl,
        'startDate': Timestamp.fromDate(startDate),
        'endDate': Timestamp.fromDate(endDate),
        'status': status.name,
        'createdBy': createdBy,
        'createdAt': Timestamp.fromDate(createdAt),
        'budgetEstimate': budgetEstimate,
        'currency': currency,
        'memberIds': memberIds,
        'searchKey': '${title.toLowerCase()} ${description.toLowerCase()}',
      };

  int get days => endDate.difference(startDate).inDays + 1;

  bool get isUpcoming => status == TripStatus.upcoming || status == TripStatus.planning;
}

enum PinCategory { stay, eat, sight, activity, transit }

class TripPin {
  final String id;
  final String tripId;
  final String title;
  final String note;
  final double lat;
  final double lng;
  final PinCategory category;
  final int order;
  final DateTime? visitedAt;
  final String? photoUrl;
  final String createdBy;

  const TripPin({
    required this.id,
    required this.tripId,
    required this.title,
    this.note = '',
    required this.lat,
    required this.lng,
    this.category = PinCategory.sight,
    this.order = 0,
    this.visitedAt,
    this.photoUrl,
    required this.createdBy,
  });

  static PinCategory _parseCat(dynamic v) {
    if (v is String) for (final c in PinCategory.values) if (c.name == v) return c;
    return PinCategory.sight;
  }

  factory TripPin.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TripPin(
      id: doc.id,
      tripId: data['tripId'] ?? '',
      title: data['title'] ?? '',
      note: data['note'] ?? '',
      lat: (data['lat'] ?? 0).toDouble(),
      lng: (data['lng'] ?? 0).toDouble(),
      category: _parseCat(data['category']),
      order: data['order'] ?? 0,
      visitedAt: (data['visitedAt'] as Timestamp?)?.toDate(),
      photoUrl: data['photoUrl'],
      createdBy: data['createdBy'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() => {
        'tripId': tripId,
        'title': title,
        'note': note,
        'lat': lat,
        'lng': lng,
        'category': category.name,
        'order': order,
        'createdBy': createdBy,
        if (visitedAt != null) 'visitedAt': Timestamp.fromDate(visitedAt!),
        if (photoUrl != null) 'photoUrl': photoUrl,
      };

  bool get isVisited => visitedAt != null;

  String get emoji {
    switch (category) {
      case PinCategory.stay:
        return '🏨';
      case PinCategory.eat:
        return '🍽️';
      case PinCategory.sight:
        return '📍';
      case PinCategory.activity:
        return '🎭';
      case PinCategory.transit:
        return '✈️';
    }
  }
}
