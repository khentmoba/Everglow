import 'package:cloud_firestore/cloud_firestore.dart';

/// How often a subscription bills. The renewal date rolls forward by
/// this step, so "renews in N days" stays correct without edits.
enum SubCycle {
  monthly('Monthly', '/mo'),
  yearly('Yearly', '/yr');

  final String displayName;
  final String suffix;
  const SubCycle(this.displayName, this.suffix);
}

/// Who pays for a subscription.
enum SubPayer {
  khent('Khent'),
  clair('Clair'),
  shared('Shared');

  final String displayName;
  const SubPayer(this.displayName);
}

/// One shared subscription (Netflix, Spotify, iCloud…).
///
/// Prices are always Philippine pesos — every sub the couple holds
/// bills in PHP, so there is no currency field to get wrong.
class Subscription {
  final String id;
  final String name;
  final double price;
  final DateTime renewalDate;
  final SubCycle cycle;
  final SubPayer payer;
  final String createdBy;
  final DateTime createdAt;

  const Subscription({
    required this.id,
    required this.name,
    this.price = 0,
    required this.renewalDate,
    this.cycle = SubCycle.monthly,
    this.payer = SubPayer.shared,
    required this.createdBy,
    required this.createdAt,
  });

  factory Subscription.fromFirestore(DocumentSnapshot doc) =>
      Subscription.fromMap(doc.data() as Map<String, dynamic>? ?? const {}, doc.id);

  factory Subscription.fromMap(Map<String, dynamic> data, String id) {
    // Tolerate missing/odd-typed fields: one malformed doc must never
    // crash the watchAll stream and take the whole list down.
    DateTime? asDate(dynamic v) => v is Timestamp ? v.toDate() : null;
    double asPrice(dynamic v) {
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v.trim()) ?? 0;
      return 0;
    }

    return Subscription(
      id: id,
      name: data['name'] is String ? data['name'] as String : '',
      price: asPrice(data['price']),
      renewalDate: asDate(data['renewalDate']) ?? DateTime.now(),
      cycle: SubCycle.values.firstWhere(
        (c) => c.name == data['cycle'],
        orElse: () => SubCycle.monthly,
      ),
      payer: SubPayer.values.firstWhere(
        (p) => p.name == data['payer'],
        orElse: () => SubPayer.shared,
      ),
      createdBy: data['createdBy'] is String ? data['createdBy'] : '',
      createdAt: asDate(data['createdAt']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'price': price,
      'renewalDate': Timestamp.fromDate(renewalDate),
      'cycle': cycle.name,
      'payer': payer.name,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  Subscription copyWith({
    String? name,
    double? price,
    DateTime? renewalDate,
    SubCycle? cycle,
    SubPayer? payer,
  }) {
    return Subscription(
      id: id,
      name: name ?? this.name,
      price: price ?? this.price,
      renewalDate: renewalDate ?? this.renewalDate,
      cycle: cycle ?? this.cycle,
      payer: payer ?? this.payer,
      createdBy: createdBy,
      createdAt: createdAt,
    );
  }

  /// Next renewal on or after today, rolling forward by [cycle].
  /// A renewal due today counts as today ("renews today"), not next month.
  DateTime nextRenewal({DateTime? now}) {
    final today = _dateOnly(now ?? DateTime.now());
    var next = _dateOnly(renewalDate);
    var guard = 0;
    while (next.isBefore(today) && guard < 1200) {
      next = cycle == SubCycle.monthly ? _addMonths(next, 1) : _addYears(next, 1);
      guard++;
    }
    return next;
  }

  /// Whole days until [nextRenewal] (0 = renews today).
  int daysUntilRenewal({DateTime? now}) {
    final today = _dateOnly(now ?? DateTime.now());
    return nextRenewal(now: now).difference(today).inDays;
  }

  /// True when the next renewal is within a week (Motchi's warning window).
  bool get isDueSoon => daysUntilRenewal() <= 7;

  /// Normalized monthly cost, so yearly subs fold into the monthly total.
  double get monthlyCost => cycle == SubCycle.monthly ? price : price / 12;

  /// Short "₱549/mo" style label (caller formats the number).
  String get cycleSuffix => cycle.suffix;
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime _addMonths(DateTime d, int months) {
  final m = d.month - 1 + months;
  final y = d.year + m ~/ 12;
  final mm = m % 12 + 1;
  final lastDay = DateTime(y, mm + 1, 0).day;
  return DateTime(y, mm, d.day.clamp(1, lastDay));
}

DateTime _addYears(DateTime d, int years) {
  final lastDay = DateTime(d.year + years, d.month + 1, 0).day;
  return DateTime(d.year + years, d.month, d.day.clamp(1, lastDay));
}
