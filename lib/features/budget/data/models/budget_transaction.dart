import 'package:cloud_firestore/cloud_firestore.dart';

enum TransactionType { expense, income }

enum SplitMode { equal, khent, clair, custom }

class BudgetTransaction {
  final String id;
  final String title;
  final double amount; // negative for expense? We store positive amount + type
  final TransactionType type;
  final String category; // e.g., Food, Transport, Entertainment
  final String paidBy; // username
  final SplitMode split;
  final Map<String, double>? customSplit; // username -> ratio
  final DateTime date;
  final String note;
  final String? receiptUrl;

  const BudgetTransaction({
    required this.id,
    required this.title,
    required this.amount,
    this.type = TransactionType.expense,
    this.category = 'Other',
    required this.paidBy,
    this.split = SplitMode.equal,
    this.customSplit,
    required this.date,
    this.note = '',
    this.receiptUrl,
  });

  static TransactionType _parseType(dynamic v) => v == 'income' ? TransactionType.income : TransactionType.expense;
  static SplitMode _parseSplit(dynamic v) {
    if (v is String) for (final s in SplitMode.values) if (s.name == v) return s;
    return SplitMode.equal;
  }

  factory BudgetTransaction.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BudgetTransaction(
      id: doc.id,
      title: data['title'] ?? '',
      amount: (data['amount'] ?? 0).toDouble(),
      type: _parseType(data['type']),
      category: data['category'] ?? 'Other',
      paidBy: data['paidBy'] ?? '',
      split: _parseSplit(data['split']),
      customSplit: data['customSplit'] != null ? Map<String, double>.from((data['customSplit'] as Map).map((k, v) => MapEntry(k.toString(), (v as num).toDouble()))) : null,
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      note: data['note'] ?? '',
      receiptUrl: data['receiptUrl'],
    );
  }

  Map<String, dynamic> toFirestore() => {
        'title': title,
        'amount': amount,
        'type': type.name,
        'category': category,
        'paidBy': paidBy,
        'split': split.name,
        if (customSplit != null) 'customSplit': customSplit,
        'date': Timestamp.fromDate(date),
        'note': note,
        if (receiptUrl != null) 'receiptUrl': receiptUrl,
        'monthKey': '${date.year}-${date.month.toString().padLeft(2, '0')}',
      };

  double get signedAmount => type == TransactionType.expense ? -amount : amount;

  // IHateMoney: compute how much each owes
  Map<String, double> get splitAmounts {
    if (split == SplitMode.equal) return {'khentsgdz': amount / 2, 'clairjassen': amount / 2};
    if (split == SplitMode.khent) return {'khentsgdz': amount, 'clairjassen': 0};
    if (split == SplitMode.clair) return {'khentsgdz': 0, 'clairjassen': amount};
    if (split == SplitMode.custom && customSplit != null) {
      final totalRatio = customSplit!.values.fold(0.0, (a, b) => a + b);
      if (totalRatio == 0) return {'khentsgdz': amount / 2, 'clairjassen': amount / 2};
      return customSplit!.map((k, v) => MapEntry(k, amount * (v / totalRatio)));
    }
    return {'khentsgdz': amount / 2, 'clairjassen': amount / 2};
  }
}

class BudgetCategory {
  final String name;
  final String emoji;
  final String colorHex;
  const BudgetCategory(this.name, this.emoji, this.colorHex);
}

const budgetCategories = [
  BudgetCategory('Food', '🍜', '#F0A500'),
  BudgetCategory('Transport', '🚕', '#7EE8D2'),
  BudgetCategory('Entertainment', '🎬', '#B79CED'),
  BudgetCategory('Shopping', '🛍️', '#FF6F91'),
  BudgetCategory('Bills', '💡', '#4ADE80'),
  BudgetCategory('Travel', '✈️', '#60A5FA'),
  BudgetCategory('Health', '🏥', '#F472B6'),
  BudgetCategory('Other', '💫', '#D4B5D6'),
];
