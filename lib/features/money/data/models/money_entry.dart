import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

/// Expense vs income.
enum MoneyType { expense, income }

/// Peso-first categories. Kept small so Clair can pick in one tap.
class MoneyCategories {
  MoneyCategories._();

  static const expense = [
    'Food',
    'Transport',
    'Shopping',
    'Bills',
    'Dates',
    'Fun',
    'Health',
    'Other',
  ];

  static const income = ['Allowance', 'Salary', 'Gift', 'Other'];

  static const emoji = {
    'Food': '🍽️',
    'Transport': '🛵',
    'Shopping': '🛍️',
    'Bills': '🧾',
    'Dates': '💕',
    'Fun': '🎮',
    'Health': '💊',
    'Allowance': '💌',
    'Salary': '💼',
    'Gift': '🎁',
    'Other': '✨',
  };

  static String iconFor(String category) => emoji[category] ?? '✨';
}

final _pesoFormat = NumberFormat('#,##0', 'en_PH');

/// "₱1,250" — no decimals, pesos don't need centavos here.
String formatPeso(num amount) => '₱${_pesoFormat.format(amount)}';

/// One shared-wallet entry. Collection: `budget_transactions`.
class MoneyEntry {
  final String id;
  final MoneyType type;
  final double amount;
  final String category;
  final String note;
  final String author;
  final DateTime createdAt;

  const MoneyEntry({
    required this.id,
    required this.type,
    required this.amount,
    required this.category,
    this.note = '',
    required this.author,
    required this.createdAt,
  });

  factory MoneyEntry.fromFirestore(DocumentSnapshot doc) =>
      MoneyEntry.fromMap(doc.data() as Map<String, dynamic>? ?? const {}, doc.id);

  factory MoneyEntry.fromMap(Map<String, dynamic> data, String id) {
    return MoneyEntry(
      id: id,
      type: _parseType(data['type']),
      amount: _parseAmount(data['amount']),
      category: data['category']?.toString() ?? 'Other',
      note: data['note']?.toString() ?? '',
      author: data['author']?.toString() ?? '',
      createdAt: _parseTimestamp(data['createdAt']),
    );
  }

  static MoneyType _parseType(dynamic value) {
    if (value?.toString().toLowerCase() == 'income') return MoneyType.income;
    return MoneyType.expense;
  }

  static double _parseAmount(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  static DateTime _parseTimestamp(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (_) {
        return DateTime.now();
      }
    }
    return DateTime.now();
  }

  Map<String, dynamic> toFirestore() {
    return {
      'type': type.name,
      'amount': amount,
      'category': category,
      'note': note,
      'author': author.toLowerCase(),
      'createdAt': FieldValue.serverTimestamp(),
      'monthKey': _monthKey(DateTime.now()),
    };
  }

  static String _monthKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}';
}

/// Monthly budget cap for one category. Collection: `budget_limits`,
/// doc id = category name (e.g. "Food").
class BudgetLimit {
  final String category;
  final double amount;

  const BudgetLimit({required this.category, required this.amount});

  factory BudgetLimit.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? const {};
    final amount = data['amount'];
    return BudgetLimit(
      category: data['category']?.toString() ?? doc.id,
      amount: amount is num
          ? amount.toDouble()
          : double.tryParse(amount?.toString() ?? '') ?? 0,
    );
  }
}

/// Pure monthly math — tested, no Firestore here.
class MonthlyTotal {
  final double income;
  final double expense;
  const MonthlyTotal({this.income = 0, this.expense = 0});
  double get balance => income - expense;
}

MonthlyTotal summarizeMonth(List<MoneyEntry> entries, DateTime month) {
  var income = 0.0;
  var expense = 0.0;
  for (final e in entries) {
    if (e.createdAt.year != month.year || e.createdAt.month != month.month) {
      continue;
    }
    if (e.type == MoneyType.income) {
      income += e.amount;
    } else {
      expense += e.amount;
    }
  }
  return MonthlyTotal(income: income, expense: expense);
}

/// Expense totals per category for [month].
Map<String, double> spentByCategory(List<MoneyEntry> entries, DateTime month) {
  final out = <String, double>{};
  for (final e in entries) {
    if (e.type != MoneyType.expense) continue;
    if (e.createdAt.year != month.year || e.createdAt.month != month.month) {
      continue;
    }
    out[e.category] = (out[e.category] ?? 0) + e.amount;
  }
  return out;
}
