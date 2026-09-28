import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

/// One page per lakad: packing list + budget + places live on a single
/// [Trip] doc (collection `travel_trips`, couple-only) so planning stays
/// in Everglow instead of scattered across chat.
///
/// Sub-items are embedded arrays — one stream per trip, no subcollections,
/// no extra indexes. Sections update one field at a time so Khent ticking
/// packing never clobbers Clair adding an expense.
class Trip {
  final String id;
  final String title;
  final String destination;
  final DateTime? startDate;
  final DateTime? endDate;
  final String notes;
  final double budgetTotal;
  final List<TripPackItem> packing;
  final List<TripExpense> expenses;
  final List<TripPlace> places;
  final String createdBy;
  final DateTime createdAt;

  const Trip({
    required this.id,
    required this.title,
    this.destination = '',
    this.startDate,
    this.endDate,
    this.notes = '',
    this.budgetTotal = 0,
    this.packing = const [],
    this.expenses = const [],
    this.places = const [],
    required this.createdBy,
    required this.createdAt,
  });

  /// Client-side id for embedded sub-items (no doc ids inside arrays).
  static String newId() =>
      '${DateTime.now().microsecondsSinceEpoch}${Random().nextInt(1 << 20)}';

  factory Trip.fromFirestore(DocumentSnapshot doc) =>
      Trip.fromMap(doc.data() as Map<String, dynamic>? ?? const {}, doc.id);

  factory Trip.fromMap(Map<String, dynamic> data, String id) {
    // Tolerate missing/odd-typed fields: one malformed doc must never
    // crash the trips stream and blank the whole Trip Kit.
    DateTime? asDate(dynamic v) => v is Timestamp ? v.toDate() : null;
    double asMoney(dynamic v) =>
        v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
    List<T> asList<T>(
      dynamic v,
      T Function(Map<String, dynamic>) parse,
    ) {
      if (v is! List) return <T>[];
      final out = <T>[];
      for (final e in v) {
        if (e is Map<String, dynamic>) {
          try {
            out.add(parse(e));
          } catch (_) {
            // Skip one bad sub-item; keep the rest of the trip readable.
          }
        } else if (e is Map) {
          try {
            out.add(parse(Map<String, dynamic>.from(e)));
          } catch (_) {
            // Skip one bad sub-item; keep the rest of the trip readable.
          }
        }
      }
      return out;
    }

    return Trip(
      id: id,
      title: data['title'] is String ? data['title'] as String : '',
      destination:
          data['destination'] is String ? data['destination'] as String : '',
      startDate: asDate(data['startDate']),
      endDate: asDate(data['endDate']),
      notes: data['notes'] is String ? data['notes'] as String : '',
      budgetTotal: asMoney(data['budgetTotal']),
      packing: asList(data['packing'], TripPackItem.fromMap),
      expenses: asList(data['expenses'], TripExpense.fromMap),
      places: asList(data['places'], TripPlace.fromMap),
      createdBy: data['createdBy'] is String ? data['createdBy'] : '',
      createdAt: asDate(data['createdAt']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'destination': destination,
      if (startDate != null) 'startDate': Timestamp.fromDate(startDate!),
      if (endDate != null) 'endDate': Timestamp.fromDate(endDate!),
      'notes': notes,
      'budgetTotal': budgetTotal,
      'packing': packing.map((e) => e.toMap()).toList(),
      'expenses': expenses.map((e) => e.toMap()).toList(),
      'places': places.map((e) => e.toMap()).toList(),
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  Trip copyWith({
    String? title,
    String? destination,
    DateTime? startDate,
    DateTime? endDate,
    String? notes,
    double? budgetTotal,
    List<TripPackItem>? packing,
    List<TripExpense>? expenses,
    List<TripPlace>? places,
    bool clearStartDate = false,
    bool clearEndDate = false,
  }) {
    return Trip(
      id: id,
      title: title ?? this.title,
      destination: destination ?? this.destination,
      startDate: clearStartDate ? null : (startDate ?? this.startDate),
      endDate: clearEndDate ? null : (endDate ?? this.endDate),
      notes: notes ?? this.notes,
      budgetTotal: budgetTotal ?? this.budgetTotal,
      packing: packing ?? this.packing,
      expenses: expenses ?? this.expenses,
      places: places ?? this.places,
      createdBy: createdBy,
      createdAt: createdAt,
    );
  }

  // ── Computed helpers for cards ──────────────────────────────

  int get packedCount => packing.where((e) => e.packed).length;

  double get spentTotal => expenses.fold(0, (total, e) => total + e.amount);

  double get remaining => budgetTotal - spentTotal;

  /// 0..1 spent vs budget; 0 when no budget set.
  double get budgetProgress {
    if (budgetTotal <= 0) return 0;
    return (spentTotal / budgetTotal).clamp(0.0, 1.0);
  }

  bool get overBudget => budgetTotal > 0 && spentTotal > budgetTotal;

  int get visitedCount => places.where((e) => e.done).length;
}

/// One packing checklist row.
class TripPackItem {
  final String id;
  final String label;
  final bool packed;
  final String? packedBy;

  const TripPackItem({
    required this.id,
    required this.label,
    this.packed = false,
    this.packedBy,
  });

  factory TripPackItem.fromMap(Map<String, dynamic> data) {
    return TripPackItem(
      id: data['id'] is String ? data['id'] as String : Trip.newId(),
      label: data['label'] is String ? data['label'] as String : '',
      packed: data['packed'] is bool ? data['packed'] as bool : false,
      packedBy: data['packedBy'] is String ? data['packedBy'] as String : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'label': label,
      'packed': packed,
      if (packedBy != null) 'packedBy': packedBy,
    };
  }

  TripPackItem copyWith({String? label, bool? packed, String? packedBy}) {
    return TripPackItem(
      id: id,
      label: label ?? this.label,
      packed: packed ?? this.packed,
      packedBy: packed ?? this.packed ? (packedBy ?? this.packedBy) : null,
    );
  }
}

/// One budget expense.
class TripExpense {
  final String id;
  final String label;
  final double amount;
  final String? paidBy;

  const TripExpense({
    required this.id,
    required this.label,
    this.amount = 0,
    this.paidBy,
  });

  factory TripExpense.fromMap(Map<String, dynamic> data) {
    final raw = data['amount'];
    return TripExpense(
      id: data['id'] is String ? data['id'] as String : Trip.newId(),
      label: data['label'] is String ? data['label'] as String : '',
      amount: raw is num ? raw.toDouble() : double.tryParse('$raw') ?? 0,
      paidBy: data['paidBy'] is String ? data['paidBy'] as String : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'label': label,
      'amount': amount,
      if (paidBy != null) 'paidBy': paidBy,
    };
  }
}

/// One place to visit.
class TripPlace {
  final String id;
  final String name;
  final String note;
  final bool done;

  const TripPlace({
    required this.id,
    required this.name,
    this.note = '',
    this.done = false,
  });

  factory TripPlace.fromMap(Map<String, dynamic> data) {
    return TripPlace(
      id: data['id'] is String ? data['id'] as String : Trip.newId(),
      name: data['name'] is String ? data['name'] as String : '',
      note: data['note'] is String ? data['note'] as String : '',
      done: data['done'] is bool ? data['done'] as bool : false,
    );
  }

  Map<String, dynamic> toMap() {
    return {'id': id, 'name': name, 'note': note, 'done': done};
  }

  TripPlace copyWith({String? name, String? note, bool? done}) {
    return TripPlace(
      id: id,
      name: name ?? this.name,
      note: note ?? this.note,
      done: done ?? this.done,
    );
  }
}
