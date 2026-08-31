import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/everglow/everglow_background.dart';
import '../../../../shared/widgets/everglow/everglow_empty_state.dart';
import '../../../../shared/widgets/everglow/everglow_feature_header.dart';
import '../../../../shared/widgets/everglow/everglow_segmented_control.dart';
import '../../data/models/budget_transaction.dart';
import '../../data/services/budget_service.dart';

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});
  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  int _tab = 0;
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(children: [
        const Positioned.fill(
            child: EverglowBackground(
                baseColor: AppColors.inkDeep,
                glows: [
                  RadialGlow(color: AppColors.warmAmber, alignment: Alignment(-0.62, -0.78), size: 0.88, opacity: 0.14),
                  RadialGlow(color: AppColors.deepRose, alignment: Alignment(0.85, -0.35), size: 0.62, opacity: 0.07)
                ],
                showPetals: true)),
        SafeArea(
            child: Column(children: [
          EverglowFeatureHeader(
              title: 'Budget',
              subtitle: 'Actual \u00d7 IHateMoney \u00b7 shared finances',
              icon: Icons.account_balance_wallet_rounded,
              hue: AppColors.warmAmber,
              actions: [IconButton(tooltip: 'Add', onPressed: () => _openSheet(auth, null), icon: const Icon(Icons.add_rounded, color: AppColors.blushGold))]),
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: EverglowSegmentedControl(
                  selectedIndex: _tab,
                  onChanged: (i) => setState(() => _tab = i),
                  activeColor: AppColors.warmAmber,
                  items: const [
                    SegmentItem('Transactions', Icons.receipt_long_rounded),
                    SegmentItem('Budget', Icons.pie_chart_rounded),
                    SegmentItem('Split', Icons.handshake_rounded)
                  ])),
          const SizedBox(height: 10),
          _MonthNav(
              month: _month,
              onPrev: () => setState(() => _month = DateTime(_month.year, _month.month - 1)),
              onNext: () => setState(() => _month = DateTime(_month.year, _month.month + 1)),
              onToday: () => setState(() => _month = DateTime(DateTime.now().year, DateTime.now().month))),
          const SizedBox(height: 8),
          Expanded(
              child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: _tab == 0
                      ? _TxTab(key: ValueKey('tx-${_month.month}-${_month.year}'), month: _month, onEdit: (tx) => _openSheet(auth, tx))
                      : _tab == 1
                          ? _BudgetTab(key: ValueKey('bd-${_month.month}-${_month.year}'), month: _month)
                          : _SplitTab(key: ValueKey('sp-${_month.month}-${_month.year}'), month: _month)))
        ]))
      ]),
      floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _openSheet(auth, null),
          backgroundColor: AppColors.warmAmber,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add_rounded, size: 20),
          label: Text('Add', style: AppTypography.outfitBold.copyWith(fontSize: 13, color: Colors.white))),
    );
  }

  void _openSheet(AuthService auth, BudgetTransaction? ex) {
    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _TxSheet(auth: auth, existing: ex));
  }
}

class _MonthNav extends StatelessWidget {
  final DateTime month;
  final VoidCallback onPrev, onNext, onToday;
  const _MonthNav({required this.month, required this.onPrev, required this.onNext, required this.onToday});
  @override
  Widget build(BuildContext context) {
    final isNow = month.year == DateTime.now().year && month.month == DateTime.now().month;
    return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            decoration: BoxDecoration(color: AppColors.inkDeep.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.moonlight.withValues(alpha: 0.09))),
            child: Row(children: [
              _btn(Icons.chevron_left_rounded, onPrev),
              Expanded(
                  child: Center(
                      child: Column(children: [
                Text('${_mName(month.month)} ${month.year}', style: AppTypography.outfitBold.copyWith(fontSize: 14, color: AppTheme.petalWhite)),
                Text(isNow ? 'this month' : '1-${DateTime(month.year, month.month + 1, 0).day} \u00b7 ${_mShort(month.month)}', style: AppTypography.outfitWhite.copyWith(fontSize: 10, color: AppTheme.petalWhite.withValues(alpha: 0.46)))
              ]))),
              _btn(Icons.chevron_right_rounded, onNext),
              const SizedBox(width: 6),
              GestureDetector(
                  onTap: onToday,
                  child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                          color: isNow ? AppColors.warmAmber.withValues(alpha: 0.16) : AppColors.moonlight.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: isNow ? AppColors.warmAmber.withValues(alpha: 0.32) : AppColors.border)),
                      child: Text('Today', style: AppTypography.outfitBold.copyWith(fontSize: 11, color: isNow ? AppColors.warmAmber : AppTheme.petalWhite.withValues(alpha: 0.7)))))
            ])));
  }

  Widget _btn(IconData i, VoidCallback t) => InkWell(
      onTap: t,
      borderRadius: BorderRadius.circular(10),
      child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(color: AppColors.moonlight.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.moonlight.withValues(alpha: 0.08))),
          child: Icon(i, size: 18, color: AppColors.blushGold)));
}

// helpers
String _fmt(double v) {
  final a = v.abs().toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
  return '${v < 0 ? '-' : ''}\u20b1$a';
}

String _mName(int m) => const ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'][m - 1];
String _mShort(int m) => const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][m - 1];
String _wShort(int w) => const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][w - 1];
String _catE(String c) => budgetCategories.firstWhere((e) => e.name == c, orElse: () => budgetCategories.last).emoji;
Color _catC(String c) => Color(int.parse(budgetCategories.firstWhere((e) => e.name == c, orElse: () => budgetCategories.last).colorHex.replaceAll('#', '0xFF')));
String _dateLbl(DateTime d) {
  final n = DateTime.now();
  final t = DateTime(n.year, n.month, n.day);
  final x = DateTime(d.year, d.month, d.day);
  final diff = t.difference(x).inDays;
  if (diff == 0) return 'Today \u00b7 ${_mShort(d.month)} ${d.day}';
  if (diff == 1) return 'Yesterday \u00b7 ${_mShort(d.month)} ${d.day}';
  return '${_wShort(d.weekday)} \u00b7 ${_mShort(d.month)} ${d.day} \u00b7 ${d.year}';
}

// Transactions tab
class _TxTab extends StatefulWidget {
  final DateTime month;
  final ValueChanged<BudgetTransaction> onEdit;
  const _TxTab({super.key, required this.month, required this.onEdit});
  @override
  State<_TxTab> createState() => _TxTabState();
}

class _TxTabState extends State<_TxTab> {
  String _f = 'all';
  String _q = '';
  @override
  Widget build(BuildContext context) {
    final svc = BudgetService();
    return StreamBuilder<List<BudgetTransaction>>(
        stream: svc.watchMonth(widget.month),
        builder: (c, s) {
          if (s.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: AppColors.warmAmber, strokeWidth: 2));
          final all = s.data ?? [];
          final inc = svc.totalIncome(all);
          final exp = svc.totalExpense(all);
          final bal = inc - exp;
          var fil = all.where((t) {
            if (_f == 'expense' && t.type != TransactionType.expense) return false;
            if (_f == 'income' && t.type != TransactionType.income) return false;
            if (_q.isNotEmpty) {
              final q = _q.toLowerCase();
              if (!t.title.toLowerCase().contains(q) && !t.category.toLowerCase().contains(q) && !t.note.toLowerCase().contains(q)) return false;
            }
            return true;
          }).toList();
          final g = <String, List<BudgetTransaction>>{};
          for (final t in fil) {
            final k = '${t.date.year}-${t.date.month.toString().padLeft(2, '0')}-${t.date.day.toString().padLeft(2, '0')}';
            g.putIfAbsent(k, () => []).add(t);
          }
          final keys = g.keys.toList()..sort((a, b) => b.compareTo(a));
          if (all.isEmpty) {
            return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                child: Column(children: [
                  _SumCard(income: inc, expense: exp, balance: bal, count: all.length),
                  const SizedBox(height: 18),
                  const EverglowEmptyState(icon: Icons.receipt_long_rounded, title: 'No transactions', subtitle: 'Add your first expense \u2014 Actual will track it, IHateMoney will split it.'),
                  const SizedBox(height: 14),
                  _TipCard()
                ]));
          }
          return ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 96), children: [
            _SumCard(income: inc, expense: exp, balance: bal, count: all.length),
            const SizedBox(height: 12),
            _Filter(f: _f, onF: (v) => setState(() => _f = v), q: _q, onQ: (v) => setState(() => _q = v), expC: all.where((t) => t.type == TransactionType.expense).length, incC: all.where((t) => t.type == TransactionType.income).length),
            const SizedBox(height: 12),
            if (fil.isEmpty)
              Padding(padding: const EdgeInsets.symmetric(vertical: 32), child: Center(child: Text('No matches', style: AppTypography.outfitWhite.copyWith(color: AppTheme.petalWhite.withValues(alpha: 0.5)))))
            else
              ...keys.map((k) {
                final list = g[k]!;
                final d = list.first.date;
                final de = list.where((t) => t.type == TransactionType.expense).fold(0.0, (a, b) => a + b.amount);
                final di = list.where((t) => t.type == TransactionType.income).fold(0.0, (a, b) => a + b.amount);
                return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Padding(
                      padding: const EdgeInsets.fromLTRB(4, 10, 4, 8),
                      child: Row(children: [
                        Text(_dateLbl(d), style: AppTypography.outfitBold.copyWith(fontSize: 11, color: AppTheme.petalWhite.withValues(alpha: 0.78))),
                        const Spacer(),
                        if (de > 0) Text('-${_fmt(de)}', style: AppTypography.outfitBold.copyWith(fontSize: 11, color: Colors.redAccent.withValues(alpha: 0.9))),
                        if (de > 0 && di > 0) const SizedBox(width: 6),
                        if (di > 0) Text('+${_fmt(di)}', style: AppTypography.outfitBold.copyWith(fontSize: 11, color: AppColors.success))
                      ])),
                  ...list.map((t) => _Row(tx: t, onEdit: () => widget.onEdit(t)))
                ]);
              }),
            const SizedBox(height: 8),
            _Footer(income: inc, expense: exp)
          ]);
        });
  }
}

class _SumCard extends StatelessWidget {
  final double income, expense, balance;
  final int count;
  const _SumCard({required this.income, required this.expense, required this.balance, required this.count});
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          gradient: LinearGradient(colors: [AppColors.warmAmber.withValues(alpha: 0.16), AppColors.deepRose.withValues(alpha: 0.10), AppColors.inkDeep.withValues(alpha: 0.7)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.warmAmber.withValues(alpha: 0.18))),
      child: Column(children: [
        Row(children: [
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: AppColors.warmAmber.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(8)), child: Text('Actual \u00b7 Month', style: AppTypography.outfitBold.copyWith(fontSize: 10, letterSpacing: 0.6, color: AppColors.warmAmber))),
          const Spacer(),
          Text('$count ${count == 1 ? 'entry' : 'entries'}', style: AppTypography.outfitWhite.copyWith(fontSize: 10, color: AppTheme.petalWhite.withValues(alpha: 0.5)))
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _cell('Income', income, AppColors.success, Icons.arrow_downward_rounded)),
          Container(width: 1, height: 40, color: AppColors.moonlight.withValues(alpha: 0.12)),
          Expanded(child: _cell('Spent', expense, Colors.redAccent, Icons.arrow_upward_rounded)),
          Container(width: 1, height: 40, color: AppColors.moonlight.withValues(alpha: 0.12)),
          Expanded(child: _cell('Balance', balance, balance >= 0 ? AppColors.success : Colors.redAccent, Icons.account_balance_wallet_rounded))
        ])
      ]));
  Widget _cell(String l, double v, Color c, IconData i) => Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(i, size: 11, color: AppTheme.petalWhite.withValues(alpha: 0.45)), const SizedBox(width: 4), Text(l, style: AppTypography.outfitWhite.copyWith(fontSize: 10, color: AppTheme.petalWhite.withValues(alpha: 0.55)))]),
        const SizedBox(height: 4),
        Text(_fmt(v), style: AppTypography.outfitBold.copyWith(fontSize: 14, color: c))
      ]);
}

class _Filter extends StatelessWidget {
  final String f;
  final ValueChanged<String> onF;
  final String q;
  final ValueChanged<String> onQ;
  final int expC, incC;
  const _Filter({required this.f, required this.onF, required this.q, required this.onQ, required this.expC, required this.incC});
  @override
  Widget build(BuildContext context) => Column(children: [
        Row(children: [
          _chip('All', f == 'all', () => onF('all')),
          const SizedBox(width: 6),
          _chip('Expenses \u00b7 $expC', f == 'expense', () => onF('expense')),
          const SizedBox(width: 6),
          _chip('Income \u00b7 $incC', f == 'income', () => onF('income'))
        ]),
        const SizedBox(height: 8),
        TextField(
            onChanged: onQ,
            style: AppTypography.outfitWhite.copyWith(color: AppTheme.petalWhite, fontSize: 13),
            decoration: InputDecoration(
                hintText: 'Search title, category, note...',
                hintStyle: AppTypography.outfitWhite.copyWith(color: AppTheme.petalWhite.withValues(alpha: 0.35), fontSize: 12),
                prefixIcon: Icon(Icons.search_rounded, size: 16, color: AppTheme.petalWhite.withValues(alpha: 0.45)),
                filled: true,
                fillColor: AppColors.inkDeep.withValues(alpha: 0.45),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.moonlight.withValues(alpha: 0.09))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.moonlight.withValues(alpha: 0.09))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.warmAmber.withValues(alpha: 0.32)))))
      ]);
  Widget _chip(String l, bool s, VoidCallback t) => GestureDetector(
      onTap: t,
      child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(color: s ? AppColors.warmAmber.withValues(alpha: 0.18) : AppColors.moonlight.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(20), border: Border.all(color: s ? AppColors.warmAmber.withValues(alpha: 0.34) : AppColors.moonlight.withValues(alpha: 0.09))),
          child: Text(l, style: AppTypography.outfitBold.copyWith(fontSize: 11, color: s ? AppColors.warmAmber : AppTheme.petalWhite.withValues(alpha: 0.68)))));
}

class _Row extends StatelessWidget {
  final BudgetTransaction tx;
  final VoidCallback onEdit;
  const _Row({required this.tx, required this.onEdit});
  @override
  Widget build(BuildContext context) {
    final isE = tx.type == TransactionType.expense;
    final acc = isE ? Colors.redAccent : AppColors.success;
    return Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(color: AppTheme.moonlight.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(14), border: Border.all(color: acc.withValues(alpha: 0.10))),
        child: InkWell(
            onTap: onEdit,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(color: _catC(tx.category).withValues(alpha: 0.14), borderRadius: BorderRadius.circular(11), border: Border.all(color: _catC(tx.category).withValues(alpha: 0.18))),
                      child: Center(child: Text(_catE(tx.category), style: const TextStyle(fontSize: 18)))),
                  const SizedBox(width: 11),
                  Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(tx.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.outfitBold.copyWith(fontSize: 13, color: AppTheme.petalWhite)),
                    const SizedBox(height: 2),
                    Row(children: [
                      Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: _catC(tx.category).withValues(alpha: 0.14), borderRadius: BorderRadius.circular(6)), child: Text(tx.category, style: AppTypography.outfitBold.copyWith(fontSize: 9, letterSpacing: 0.4, color: _catC(tx.category)))),
                      const SizedBox(width: 6),
                      Flexible(child: Text('${tx.paidBy == 'khentsgdz' ? 'Khent' : tx.paidBy == 'clairjassen' ? 'Clair' : tx.paidBy} \u00b7 ${tx.split.name}${tx.note.isNotEmpty ? ' \u00b7 ${tx.note}' : ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.outfitWhite.copyWith(fontSize: 10.5, color: AppTheme.petalWhite.withValues(alpha: 0.52))))
                    ])
                  ])),
                  const SizedBox(width: 10),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('${isE ? '-' : '+'}${_fmt(tx.amount)}', style: AppTypography.outfitBold.copyWith(fontSize: 13.5, color: acc)),
                    const SizedBox(height: 3),
                    Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                        decoration: BoxDecoration(color: acc.withValues(alpha: 0.11), borderRadius: BorderRadius.circular(20), border: Border.all(color: acc.withValues(alpha: 0.16))),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(isE ? Icons.trending_down_rounded : Icons.trending_up_rounded, size: 10, color: acc), const SizedBox(width: 3), Text(tx.type == TransactionType.income ? 'income' : tx.split.name, style: AppTypography.outfitBold.copyWith(fontSize: 9, letterSpacing: 0.3, color: acc))]))
                  ]),
                  const SizedBox(width: 6),
                  PopupMenuButton<String>(
                      icon: Icon(Icons.more_horiz_rounded, size: 16, color: AppTheme.petalWhite.withValues(alpha: 0.38)),
                      color: AppColors.velvet,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      onSelected: (v) {
                        if (v == 'edit') onEdit();
                        if (v == 'delete') _del(context);
                      },
                      itemBuilder: (_) => [
                            PopupMenuItem(value: 'edit', child: Row(children: [const Icon(Icons.edit_rounded, size: 14, color: AppColors.blushGold), const SizedBox(width: 8), Text('Edit', style: AppTypography.outfitWhite.copyWith(color: AppTheme.petalWhite, fontSize: 13))])),
                            PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline_rounded, size: 14, color: Colors.redAccent.withValues(alpha: 0.9)), const SizedBox(width: 8), Text('Delete', style: AppTypography.outfitWhite.copyWith(color: Colors.redAccent, fontSize: 13))]))
                          ])
                ]))));
  }

  void _del(BuildContext c) {
    showDialog(
        context: c,
        builder: (x) => AlertDialog(
                backgroundColor: AppColors.velvet,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                title: Text('Delete transaction?', style: AppTypography.cormorantBold.copyWith(color: AppTheme.petalWhite, fontSize: 18)),
                content: Text('\u201c${tx.title}\u201d \u2014 ${_fmt(tx.amount)} will be removed.', style: AppTypography.outfitWhite.copyWith(color: AppTheme.petalWhite.withValues(alpha: 0.7), fontSize: 13)),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(x), child: Text('Cancel', style: AppTypography.outfitBold.copyWith(color: AppTheme.petalWhite.withValues(alpha: 0.6)))),
                  ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                      onPressed: () async {
                        Navigator.pop(x);
                        await BudgetService().delete(tx.id);
                        if (c.mounted) ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text('Deleted \u201c${tx.title}\u201d', style: AppTypography.outfitWhite.copyWith(color: Colors.white)), backgroundColor: AppColors.velvet));
                      },
                      child: const Text('Delete'))
                ]));
  }
}

class _Footer extends StatelessWidget {
  final double income, expense;
  const _Footer({required this.income, required this.expense});
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(color: AppColors.inkDeep.withValues(alpha: 0.42), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.moonlight.withValues(alpha: 0.08))),
      child: Row(children: [
        Icon(Icons.receipt_long_rounded, size: 14, color: AppTheme.petalWhite.withValues(alpha: 0.45)),
        const SizedBox(width: 8),
        Text('Month total:', style: AppTypography.outfitWhite.copyWith(fontSize: 11, color: AppTheme.petalWhite.withValues(alpha: 0.55))),
        const Spacer(),
        Text('+${_fmt(income)}', style: AppTypography.outfitBold.copyWith(fontSize: 11, color: AppColors.success)),
        const SizedBox(width: 8),
        Text('-${_fmt(expense)}', style: AppTypography.outfitBold.copyWith(fontSize: 11, color: Colors.redAccent)),
        const SizedBox(width: 8),
        Container(width: 1, height: 14, color: AppColors.moonlight.withValues(alpha: 0.14)),
        const SizedBox(width: 8),
        Text(_fmt(income - expense), style: AppTypography.outfitBold.copyWith(fontSize: 12, color: (income - expense) >= 0 ? AppColors.success : Colors.redAccent))
      ]));
}

class _TipCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.twilight.withValues(alpha: 0.85), borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 30, height: 30, decoration: BoxDecoration(color: AppColors.warmAmber.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.lightbulb_rounded, size: 16, color: AppColors.warmAmber)),
        const SizedBox(width: 10),
        Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('How Actual \u00d7 IHateMoney works', style: AppTypography.outfitBold.copyWith(fontSize: 12, color: AppTheme.petalWhite)),
          const SizedBox(height: 4),
          Text('Actual tracks every peso in and out per envelope. IHateMoney then splits each expense so you always know who owes who \u2014 no spreadsheets.', style: AppTypography.outfitWhite.copyWith(fontSize: 11, height: 1.45, color: AppTheme.petalWhite.withValues(alpha: 0.64)))
        ]))
      ]));
}

// Budget tab
class _BudgetTab extends StatelessWidget {
  final DateTime month;
  const _BudgetTab({super.key, required this.month});
  @override
  Widget build(BuildContext context) {
    final svc = BudgetService();
    return StreamBuilder<List<BudgetTransaction>>(
        stream: svc.watchMonth(month),
        builder: (c, txS) {
          final txs = txS.data ?? [];
          final byCat = svc.byCategory(txs);
          final exp = svc.totalExpense(txs);
          final inc = svc.totalIncome(txs);
          return StreamBuilder<Map<String, double>>(
              stream: svc.watchBudgetLimits(month),
              builder: (c2, limS) {
                final lim = limS.data ?? {};
                final budgeted = lim.values.fold(0.0, (a, b) => a + b);
                final avail = inc - budgeted;
                return ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 96), children: [
                  Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [AppColors.warmAmber.withValues(alpha: 0.18), AppColors.deepRose.withValues(alpha: 0.12), AppColors.velvet], begin: Alignment.topLeft, end: Alignment.bottomRight),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AppColors.warmAmber.withValues(alpha: 0.18))),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.09), borderRadius: BorderRadius.circular(8)), child: Row(children: [const Icon(Icons.savings_rounded, size: 12, color: AppColors.warmAmber), const SizedBox(width: 5), Text('ENVELOPE BUDGET', style: AppTypography.outfitBold.copyWith(fontSize: 10, letterSpacing: 0.7, color: AppColors.warmAmber))])),
                          const Spacer(),
                          Text('${_mShort(month.month)} ${month.year}', style: AppTypography.outfitWhite.copyWith(fontSize: 11, color: AppTheme.petalWhite.withValues(alpha: 0.5)))
                        ]),
                        const SizedBox(height: 12),
                        Text('Available to budget', style: AppTypography.outfitWhite.copyWith(fontSize: 11, color: AppTheme.petalWhite.withValues(alpha: 0.62))),
                        const SizedBox(height: 4),
                        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Text(_fmt(avail), style: AppTypography.cormorantBold.copyWith(fontSize: 28, height: 1.0, color: avail >= 0 ? AppColors.success : Colors.redAccent)),
                          const SizedBox(width: 8),
                          Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3), decoration: BoxDecoration(color: (avail >= 0 ? AppColors.success : Colors.redAccent).withValues(alpha: 0.14), borderRadius: BorderRadius.circular(20)), child: Text(avail >= 0 ? 'ready to assign' : 'over-budget', style: AppTypography.outfitBold.copyWith(fontSize: 10, color: avail >= 0 ? AppColors.success : Colors.redAccent))))
                        ]),
                        const SizedBox(height: 14),
                        Row(children: [
                          Expanded(child: _s('Income', inc, AppColors.success)),
                          Container(width: 1, height: 34, color: AppColors.moonlight.withValues(alpha: 0.12)),
                          Expanded(child: _s('Budgeted', budgeted, AppColors.warmAmber)),
                          Container(width: 1, height: 34, color: AppColors.moonlight.withValues(alpha: 0.12)),
                          Expanded(child: _s('Spent', exp, Colors.redAccent))
                        ]),
                        if (budgeted == 0 && inc > 0) ...[
                          const SizedBox(height: 12),
                          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), decoration: BoxDecoration(color: AppColors.warmAmber.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)), child: Row(children: [const Icon(Icons.info_outline_rounded, size: 14, color: AppColors.warmAmber), const SizedBox(width: 8), Expanded(child: Text('You have ${_fmt(inc)} to allocate. Tap any envelope below to set its budget.', style: AppTypography.outfitWhite.copyWith(fontSize: 11, color: AppTheme.petalWhite.withValues(alpha: 0.8))))]))
                        ]
                      ])),
                  const SizedBox(height: 14),
                  Row(children: [Text('Envelopes', style: AppTypography.outfitBold.copyWith(fontSize: 12, letterSpacing: 0.4, color: AppTheme.petalWhite)), const SizedBox(width: 8), Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppColors.warmAmber, shape: BoxShape.circle)), const Spacer(), Text('tap to edit budget', style: AppTypography.outfitWhite.copyWith(fontSize: 10, color: AppTheme.petalWhite.withValues(alpha: 0.42)))]),
                  const SizedBox(height: 10),
                  ...budgetCategories.map((cat) {
                    final spent = byCat[cat.name] ?? 0;
                    final bud = lim[cat.name] ?? 0;
                    final rem = bud - spent;
                    final pct = bud <= 0 ? (spent > 0 ? 1.0 : 0.0) : (spent / bud).clamp(0.0, 1.0);
                    final over = bud > 0 && spent > bud;
                    final half = bud > 0 && pct > 0.75 && !over;
                    return _EnvRow(cat: cat, spent: spent, bud: bud, rem: rem, pct: pct.toDouble(), over: over, half: half, month: month);
                  }),
                  const SizedBox(height: 14),
                  _BudgetFooter(byCat: byCat, lim: lim, inc: inc, exp: exp)
                ]);
              });
        });
  }

  Widget _s(String l, double v, Color c) => Column(children: [Text(l, style: AppTypography.outfitWhite.copyWith(fontSize: 10, color: AppTheme.petalWhite.withValues(alpha: 0.55))), const SizedBox(height: 4), Text(_fmt(v), style: AppTypography.outfitBold.copyWith(fontSize: 13, color: c))]);
}

class _EnvRow extends StatelessWidget {
  final BudgetCategory cat;
  final double spent, bud, rem, pct;
  final bool over, half;
  final DateTime month;
  const _EnvRow({required this.cat, required this.spent, required this.bud, required this.rem, required this.pct, required this.over, required this.half, required this.month});
  @override
  Widget build(BuildContext context) {
    final base = _catC(cat.name);
    final bar = over ? Colors.redAccent : half ? AppColors.warmAmber : base;
    final remC = over ? Colors.redAccent : rem == 0 ? AppTheme.petalWhite.withValues(alpha: 0.55) : AppColors.success;
    return Container(
        margin: const EdgeInsets.only(bottom: 9),
        decoration: BoxDecoration(color: over ? Colors.redAccent.withValues(alpha: 0.07) : AppTheme.moonlight.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(14), border: Border.all(color: over ? Colors.redAccent.withValues(alpha: 0.18) : AppColors.moonlight.withValues(alpha: 0.09))),
        child: InkWell(
            onTap: () => _edit(context),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(width: 36, height: 36, decoration: BoxDecoration(color: base.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(9), border: Border.all(color: base.withValues(alpha: 0.18))), child: Center(child: Text(cat.emoji, style: const TextStyle(fontSize: 16)))),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(cat.name, style: AppTypography.outfitBold.copyWith(fontSize: 13, color: AppTheme.petalWhite)),
                      Text(bud == 0 ? 'No budget set \u00b7 ${_fmt(spent)} spent' : '${_fmt(spent)} of ${_fmt(bud)}', style: AppTypography.outfitWhite.copyWith(fontSize: 11, color: AppTheme.petalWhite.withValues(alpha: 0.56)))
                    ])),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text(bud == 0 ? '\u2014' : _fmt(rem), style: AppTypography.outfitBold.copyWith(fontSize: 13, color: remC)),
                      Text(bud == 0 ? 'tap to set' : (over ? '${_fmt((spent - bud).abs())} over' : rem == 0 ? 'exact' : 'left'), style: AppTypography.outfitWhite.copyWith(fontSize: 10, color: AppTheme.petalWhite.withValues(alpha: 0.48)))
                    ]),
                    const SizedBox(width: 6),
                    Icon(Icons.edit_rounded, size: 13, color: AppTheme.petalWhite.withValues(alpha: 0.32))
                  ]),
                  const SizedBox(height: 10),
                  ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Stack(children: [
                        Container(height: 7, decoration: BoxDecoration(color: AppColors.moonlight.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(6))),
                        FractionallySizedBox(widthFactor: bud == 0 ? (spent > 0 ? 1.0 : 0.0) : pct, child: Container(height: 7, decoration: BoxDecoration(color: bar, borderRadius: BorderRadius.circular(6))))
                      ])),
                  if (bud > 0) ...[
                    const SizedBox(height: 6),
                    Row(children: [
                      Text('${(pct * 100).toStringAsFixed(0)}% used', style: AppTypography.outfitBold.copyWith(fontSize: 10, color: bar)),
                      const Spacer(),
                      Text(over ? 'Over by ${_fmt(spent - bud)}' : '${_fmt(bud - spent)} remaining', style: AppTypography.outfitWhite.copyWith(fontSize: 10, color: AppTheme.petalWhite.withValues(alpha: 0.46)))
                    ])
                  ]
                ]))));
  }

  void _edit(BuildContext context) {
    final ctrl = TextEditingController(text: bud == 0 ? '' : bud.toStringAsFixed(0));
    showDialog(
        context: context,
        builder: (x) => AlertDialog(
                backgroundColor: AppColors.velvet,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                title: Row(children: [Text(cat.emoji, style: const TextStyle(fontSize: 18)), const SizedBox(width: 8), Text('${cat.name} budget', style: AppTypography.cormorantBold.copyWith(color: AppTheme.petalWhite, fontSize: 18))]),
                content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Budget for ${_mName(month.month)} ${month.year}', style: AppTypography.outfitWhite.copyWith(color: AppTheme.petalWhite.withValues(alpha: 0.6), fontSize: 12)),
                  const SizedBox(height: 12),
                  TextField(
                      controller: ctrl,
                      keyboardType: TextInputType.number,
                      autofocus: true,
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                      style: AppTypography.outfitBold.copyWith(color: AppTheme.petalWhite, fontSize: 18),
                      decoration: InputDecoration(
                          prefixText: '\u20b1 ',
                          prefixStyle: AppTypography.outfitBold.copyWith(color: AppColors.warmAmber, fontSize: 16),
                          hintText: '0',
                          hintStyle: AppTypography.outfitWhite.copyWith(color: AppTheme.petalWhite.withValues(alpha: 0.28)),
                          filled: true,
                          fillColor: AppColors.twilight,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14))),
                  const SizedBox(height: 10),
                  Wrap(spacing: 6, children: [500, 1000, 2000, 5000].map((v) => ActionChip(label: Text('+\u20b1$v', style: AppTypography.outfitBold.copyWith(fontSize: 11, color: AppColors.warmAmber)), backgroundColor: AppColors.warmAmber.withValues(alpha: 0.12), side: BorderSide(color: AppColors.warmAmber.withValues(alpha: 0.22)), onPressed: () {
                        final cur = double.tryParse(ctrl.text) ?? 0;
                        ctrl.text = (cur + v).toStringAsFixed(0);
                        ctrl.selection = TextSelection.fromPosition(TextPosition(offset: ctrl.text.length));
                      })).toList()),
                  const SizedBox(height: 8),
                  Text('Leave empty or 0 to remove budget.', style: AppTypography.outfitWhite.copyWith(fontSize: 10, color: AppTheme.petalWhite.withValues(alpha: 0.44)))
                ]),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(x), child: Text('Cancel', style: AppTypography.outfitBold.copyWith(color: AppTheme.petalWhite.withValues(alpha: 0.6)))),
                  ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.warmAmber, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                      onPressed: () async {
                        final amt = double.tryParse(ctrl.text.trim()) ?? 0;
                        Navigator.pop(x);
                        await BudgetService().setBudgetLimit(month, cat.name, amt);
                        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(amt <= 0 ? 'Removed ${cat.name} budget' : 'Set ${cat.name} to ${_fmt(amt)}', style: AppTypography.outfitWhite.copyWith(color: Colors.white)), backgroundColor: AppColors.velvet));
                      },
                      child: const Text('Save'))
                ]));
  }
}

class _BudgetFooter extends StatelessWidget {
  final Map<String, double> byCat, lim;
  final double inc, exp;
  const _BudgetFooter({required this.byCat, required this.lim, required this.inc, required this.exp});
  @override
  Widget build(BuildContext context) {
    final budg = lim.values.fold(0.0, (a, b) => a + b);
    final unbud = byCat.entries.where((e) => (lim[e.key] ?? 0) == 0).fold(0.0, (a, b) => a + b.value);
    return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.inkDeep.withValues(alpha: 0.46), borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.moonlight.withValues(alpha: 0.08))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [const Icon(Icons.insights_rounded, size: 14, color: AppColors.auroraTeal), const SizedBox(width: 6), Text('This month', style: AppTypography.outfitBold.copyWith(fontSize: 12, color: AppTheme.petalWhite))]),
          const SizedBox(height: 10),
          _r('Total budgeted', _fmt(budg), AppColors.warmAmber),
          _r('Total spent', _fmt(exp), Colors.redAccent),
          _r('Total income', _fmt(inc), AppColors.success),
          Divider(color: AppColors.moonlight.withValues(alpha: 0.09), height: 18),
          _r('Unbudgeted spending', _fmt(unbud), unbud > 0 ? Colors.redAccent : AppTheme.petalWhite.withValues(alpha: 0.5), sub: unbud > 0 ? 'assign a budget to those categories' : 'all spending is budgeted \u2713'),
          const SizedBox(height: 10),
          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), decoration: BoxDecoration(color: AppColors.twilight, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)), child: Text('Actual-style: every peso of income gets a job. Unspent budget is insight \u2014 not cash \u2014 so you see where money waits.', style: AppTypography.outfitWhite.copyWith(fontSize: 11, height: 1.45, color: AppTheme.petalWhite.withValues(alpha: 0.62))))
        ]));
  }

  Widget _r(String l, String v, Color c, {String? sub}) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(l, style: AppTypography.outfitWhite.copyWith(fontSize: 11, color: AppTheme.petalWhite.withValues(alpha: 0.62))), if (sub != null) Text(sub, style: AppTypography.outfitWhite.copyWith(fontSize: 10, color: AppTheme.petalWhite.withValues(alpha: 0.42)))])),
        Text(v, style: AppTypography.outfitBold.copyWith(fontSize: 12, color: c))
      ]));
}

// Split tab
class _SplitTab extends StatelessWidget {
  final DateTime month;
  const _SplitTab({super.key, required this.month});
  @override
  Widget build(BuildContext context) {
    final svc = BudgetService();
    return StreamBuilder<List<BudgetTransaction>>(
        stream: svc.watchMonth(month),
        builder: (c, s) {
          final txs = s.data ?? [];
          final owes = svc.computeOwes(txs);
          final kO = owes['khentsgdz'] ?? 0, cO = owes['clairjassen'] ?? 0;
          final kP = owes['khentPaid'] ?? 0, cP = owes['clairPaid'] ?? 0;
          final kS = owes['khentShare'] ?? 0, cS = owes['clairShare'] ?? 0;
          final settled = kO.abs() < 1 && cO.abs() < 1;
          final amt = kO > 0 ? kO : cO > 0 ? cO : 0;
          final debtor = kO > 1 ? 'Khent' : cO > 1 ? 'Clair' : '';
          final creditor = kO > 1 ? 'Clair' : cO > 1 ? 'Khent' : '';
          final exp = svc.totalExpense(txs);
          return ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 96), children: [
            Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [AppColors.inkDeep.withValues(alpha: 0.72), AppColors.velvet], begin: Alignment.topLeft, end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.auroraTeal.withValues(alpha: 0.16))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [Container(padding: const EdgeInsets.all(7), decoration: BoxDecoration(color: AppColors.auroraTeal.withValues(alpha: 0.14), shape: BoxShape.circle), child: const Icon(Icons.handshake_rounded, size: 14, color: AppColors.auroraTeal)), const SizedBox(width: 8), Text('IHateMoney \u00b7 Who owes who', style: AppTypography.outfitBold.copyWith(fontSize: 12, letterSpacing: 0.4, color: AppTheme.petalWhite)), const Spacer(), Text('${_mShort(month.month)} ${month.year}', style: AppTypography.outfitWhite.copyWith(fontSize: 11, color: AppTheme.petalWhite.withValues(alpha: 0.5)))]),
                  const SizedBox(height: 14),
                  Row(children: [
                    Expanded(child: _person('Khent', kP, kS, kO, AppColors.auroraTeal)),
                    Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Container(width: 40, height: 40, decoration: BoxDecoration(color: AppColors.moonlight.withValues(alpha: 0.08), shape: BoxShape.circle, border: Border.all(color: AppColors.moonlight.withValues(alpha: 0.12))), child: Icon(settled ? Icons.check_rounded : Icons.swap_horiz_rounded, size: 18, color: settled ? AppColors.success : AppColors.blushGold))),
                    Expanded(child: _person('Clair', cP, cS, cO, AppColors.blushGold))
                  ]),
                  const SizedBox(height: 14),
                  if (settled)
                    Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11), decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.success.withValues(alpha: 0.18))), child: Row(children: [const Icon(Icons.verified_rounded, size: 16, color: AppColors.success), const SizedBox(width: 8), Text('All settled for ${_mName(month.month)} \u2014 no one owes.', style: AppTypography.outfitBold.copyWith(fontSize: 12, color: AppColors.success))]))
                  else
                    Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.redAccent.withValues(alpha: 0.16), Colors.redAccent.withValues(alpha: 0.08)]), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.redAccent.withValues(alpha: 0.18))),
                        child: Row(children: [
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('$debtor owes $creditor', style: AppTypography.outfitWhite.copyWith(fontSize: 11, color: AppTheme.petalWhite.withValues(alpha: 0.6))), Text(_fmt(amt.toDouble()), style: AppTypography.cormorantBold.copyWith(fontSize: 22, height: 1.0, color: Colors.redAccent))])),
                          ElevatedButton(
                              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Settle ${_fmt(amt.toDouble())} \u00b7 add a reimbursement transaction to clear it.', style: AppTypography.outfitWhite.copyWith(color: Colors.white)), backgroundColor: AppColors.velvet, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10)),
                              child: Text('Settle up', style: AppTypography.outfitBold.copyWith(fontSize: 12, color: Colors.white)))
                        ])),
                  const SizedBox(height: 10),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), decoration: BoxDecoration(color: AppColors.moonlight.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(10)), child: Row(children: [Expanded(child: Text('Total shared spending this month', style: AppTypography.outfitWhite.copyWith(fontSize: 11, color: AppTheme.petalWhite.withValues(alpha: 0.55)))), Text(_fmt(exp), style: AppTypography.outfitBold.copyWith(fontSize: 12, color: AppTheme.petalWhite))])),
                  const SizedBox(height: 8),
                  Text('Equal split unless specified \u2014 matches IHateMoney & Actual split rules. Income is excluded from owes.', style: AppTypography.outfitWhite.copyWith(fontSize: 10, height: 1.4, color: AppTheme.petalWhite.withValues(alpha: 0.42)))
                ])),
            const SizedBox(height: 14),
            if (txs.isEmpty)
              Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18), decoration: BoxDecoration(color: AppColors.inkDeep.withValues(alpha: 0.42), borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.moonlight.withValues(alpha: 0.08))), child: Column(children: [Icon(Icons.receipt_long_rounded, size: 28, color: AppTheme.petalWhite.withValues(alpha: 0.35)), const SizedBox(height: 8), Text('No shared expenses this month', style: AppTypography.outfitBold.copyWith(fontSize: 12, color: AppTheme.petalWhite)), const SizedBox(height: 4), Text('Add transactions on the Transactions tab \u2014 we\u2019ll split every expense 50/50 by default.', textAlign: TextAlign.center, style: AppTypography.outfitWhite.copyWith(fontSize: 11, color: AppTheme.petalWhite.withValues(alpha: 0.55)))]))
            else ...[
              Row(children: [Text('How each expense was split', style: AppTypography.outfitBold.copyWith(fontSize: 12, color: AppTheme.petalWhite)), const Spacer(), Text('${txs.length} ${txs.length == 1 ? 'entry' : 'entries'}', style: AppTypography.outfitWhite.copyWith(fontSize: 11, color: AppTheme.petalWhite.withValues(alpha: 0.45)))]),
              const SizedBox(height: 8),
              ...txs.map((t) {
                final sp = t.splitAmounts;
                final isInc = t.type == TransactionType.income;
                return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(color: AppTheme.moonlight.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.moonlight.withValues(alpha: 0.08))),
                    child: Row(children: [
                      Container(width: 34, height: 34, decoration: BoxDecoration(color: (isInc ? AppColors.success : _catC(t.category)).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)), child: Center(child: Text(isInc ? '\uD83D\uDCB0' : _catE(t.category), style: const TextStyle(fontSize: 14)))),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.outfitBold.copyWith(fontSize: 12, color: AppTheme.petalWhite)),
                        Text(isInc ? 'Income \u00b7 not split' : "${t.paidBy == 'khentsgdz' ? 'Khent paid' : 'Clair paid'} \u00b7 ${t.split.name} \u00b7 Khent ${_fmt(sp['khentsgdz'] ?? 0)} \u00b7 Clair ${_fmt(sp['clairjassen'] ?? 0)}", maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.outfitWhite.copyWith(fontSize: 10.5, color: AppTheme.petalWhite.withValues(alpha: 0.52)))
                      ])),
                      const SizedBox(width: 8),
                      Text('${isInc ? '+' : '-'}${_fmt(t.amount)}', style: AppTypography.outfitBold.copyWith(fontSize: 12, color: isInc ? AppColors.success : AppTheme.petalWhite))
                    ]));
              }),
              const SizedBox(height: 10),
              Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.twilight, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Split rules', style: AppTypography.outfitBold.copyWith(fontSize: 11, color: AppTheme.petalWhite)),
                    const SizedBox(height: 6),
                    Text('\u2022 Equal: 50/50 \u2014 the default (IHateMoney).', style: AppTypography.outfitWhite.copyWith(fontSize: 11, color: AppTheme.petalWhite.withValues(alpha: 0.68))),
                    Text('\u2022 Khent / Clair: one person owes 100%.', style: AppTypography.outfitWhite.copyWith(fontSize: 11, color: AppTheme.petalWhite.withValues(alpha: 0.68))),
                    Text('\u2022 Custom: ratio via Firestore customSplit map (advanced).', style: AppTypography.outfitWhite.copyWith(fontSize: 11, color: AppTheme.petalWhite.withValues(alpha: 0.68))),
                    const SizedBox(height: 6),
                    Text('Tip: add a reimbursement transaction (e.g., \u201cClair reimburses Khent\u201d) and split it 100% to the receiver to settle.', style: AppTypography.outfitWhite.copyWith(fontSize: 10, height: 1.45, color: AppTheme.petalWhite.withValues(alpha: 0.52)))
                  ]))
            ]
          ]);
        });
  }

  Widget _person(String l, double p, double s, double o, Color h) => Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(color: h.withValues(alpha: 0.11), borderRadius: BorderRadius.circular(14), border: Border.all(color: h.withValues(alpha: 0.16))),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [Container(width: 7, height: 7, decoration: BoxDecoration(color: h, shape: BoxShape.circle)), const SizedBox(width: 6), Text(l, style: AppTypography.outfitBold.copyWith(fontSize: 11, color: h))]),
        const SizedBox(height: 6),
        Text(_fmt(p), style: AppTypography.outfitBold.copyWith(fontSize: 15, color: h)),
        Text('paid', style: AppTypography.outfitWhite.copyWith(fontSize: 10, color: AppTheme.petalWhite.withValues(alpha: 0.5))),
        const SizedBox(height: 6),
        Container(height: 1, color: h.withValues(alpha: 0.16)),
        const SizedBox(height: 6),
        Text(_fmt(s), style: AppTypography.outfitBold.copyWith(fontSize: 11, color: AppTheme.petalWhite.withValues(alpha: 0.78))),
        Text('share', style: AppTypography.outfitWhite.copyWith(fontSize: 10, color: AppTheme.petalWhite.withValues(alpha: 0.42))),
        if (o > 0.5) ...[
          const SizedBox(height: 6),
          Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3), decoration: BoxDecoration(color: Colors.redAccent.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(20)), child: Text('owes ${_fmt(o)}', style: AppTypography.outfitBold.copyWith(fontSize: 10, color: Colors.redAccent)))
        ]
      ]);
}

// Add/edit sheet
class _TxSheet extends StatefulWidget {
  final AuthService auth;
  final BudgetTransaction? existing;
  const _TxSheet({required this.auth, this.existing});
  @override
  State<_TxSheet> createState() => _TxSheetState();
}

class _TxSheetState extends State<_TxSheet> {
  late TextEditingController titleC, amtC, noteC;
  late String cat;
  late TransactionType type;
  late String paidBy;
  late SplitMode split;
  late DateTime date;
  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    titleC = TextEditingController(text: e?.title ?? '');
    amtC = TextEditingController(text: e == null ? '' : e.amount.toStringAsFixed(0));
    noteC = TextEditingController(text: e?.note ?? '');
    cat = e?.category ?? 'Food';
    type = e?.type ?? TransactionType.expense;
    paidBy = e?.paidBy ?? (widget.auth.currentUser ?? 'khentsgdz');
    split = e?.split ?? SplitMode.equal;
    date = e?.date ?? DateTime.now();
  }

  @override
  void dispose() {
    titleC.dispose();
    amtC.dispose();
    noteC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    final bot = MediaQuery.of(context).viewInsets.bottom;
    return Container(
        decoration: BoxDecoration(color: AppColors.velvet, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
        padding: EdgeInsets.fromLTRB(18, 10, 18, 18 + bot),
        child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: AppColors.moonlight.withValues(alpha: 0.28), borderRadius: BorderRadius.circular(4)))),
          const SizedBox(height: 14),
          Row(children: [
            Container(width: 36, height: 36, decoration: BoxDecoration(color: AppColors.warmAmber.withValues(alpha: 0.14), shape: BoxShape.circle, border: Border.all(color: AppColors.warmAmber.withValues(alpha: 0.24))), child: Icon(isEdit ? Icons.edit_rounded : Icons.add_rounded, size: 18, color: AppColors.warmAmber)),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(isEdit ? 'Edit transaction' : 'Add transaction', style: AppTypography.cormorantBold.copyWith(fontSize: 19, color: AppTheme.petalWhite)), Text(isEdit ? 'Update the details below' : 'Actual \u00d7 IHateMoney \u2014 we\u2019ll track and split it', style: AppTypography.outfitWhite.copyWith(fontSize: 11, color: AppTheme.petalWhite.withValues(alpha: 0.55)))])),
            IconButton(onPressed: () => Navigator.pop(context), icon: Icon(Icons.close_rounded, size: 18, color: AppTheme.petalWhite.withValues(alpha: 0.55)))
          ]),
          const SizedBox(height: 16),
          Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: AppColors.inkDeep.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.moonlight.withValues(alpha: 0.08))),
              child: Row(children: [Expanded(child: _tBtn(TransactionType.expense, 'Expense', Icons.trending_down_rounded)), const SizedBox(width: 4), Expanded(child: _tBtn(TransactionType.income, 'Income', Icons.trending_up_rounded))])),
          const SizedBox(height: 14),
          _lbl('Title'),
          const SizedBox(height: 6),
          _tf(titleC, 'e.g., Dinner at Mesa \u00b7 Grab \u00b7 Rent', TextInputType.text, null),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_lbl('Amount (PHP)'), const SizedBox(height: 6), _tf(amtC, '0', TextInputType.number, [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))], pref: '\u20b1 ')])),
            const SizedBox(width: 12),
            Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _lbl('Date'),
              const SizedBox(height: 6),
              InkWell(
                  onTap: _pick,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13), decoration: BoxDecoration(color: AppColors.twilight, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.moonlight.withValues(alpha: 0.10))), child: Row(children: [const Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.blushGold), const SizedBox(width: 8), Text('${_mShort(date.month)} ${date.day}, ${date.year}', style: AppTypography.outfitBold.copyWith(fontSize: 13, color: AppTheme.petalWhite))])))
            ]))
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _lbl('Category'),
              const SizedBox(height: 6),
              _drop<String>(value: cat, items: budgetCategories.map((c) => DropdownMenuItem(value: c.name, child: Text('${c.emoji} ${c.name}', style: AppTypography.outfitWhite.copyWith(color: AppTheme.petalWhite, fontSize: 13)))).toList(), onChanged: (v) => setState(() => cat = v!))
            ])),
            const SizedBox(width: 12),
            Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _lbl('Paid by'),
              const SizedBox(height: 6),
              _drop<String>(
                  value: paidBy,
                  items: const [DropdownMenuItem(value: 'khentsgdz', child: Text('Khent paid')), DropdownMenuItem(value: 'clairjassen', child: Text('Clair paid'))].map((e) => DropdownMenuItem(value: e.value, child: DefaultTextStyle(style: AppTypography.outfitWhite.copyWith(color: AppTheme.petalWhite, fontSize: 13), child: e.child))).toList(),
                  onChanged: (v) => setState(() => paidBy = v!))
            ]))
          ]),
          const SizedBox(height: 12),
          _lbl('Split'),
          const SizedBox(height: 6),
          Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: AppColors.inkDeep.withValues(alpha: 0.45), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.moonlight.withValues(alpha: 0.08))),
              child: Row(
                  children: SplitMode.values
                      .map((m) => Expanded(
                          child: GestureDetector(
                              onTap: () => setState(() => split = m),
                              child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 9),
                                  decoration: BoxDecoration(color: split == m ? AppColors.warmAmber.withValues(alpha: 0.18) : Colors.transparent, borderRadius: BorderRadius.circular(9), border: Border.all(color: split == m ? AppColors.warmAmber.withValues(alpha: 0.30) : Colors.transparent)),
                                  child: Text(m.name, textAlign: TextAlign.center, style: AppTypography.outfitBold.copyWith(fontSize: 11, color: split == m ? AppColors.warmAmber : AppTheme.petalWhite.withValues(alpha: 0.62)))))))
                      .toList())),
          const SizedBox(height: 12),
          _lbl('Note (optional)'),
          const SizedBox(height: 6),
          _tf(noteC, 'Add a note...', TextInputType.text, null, maxL: 2),
          const SizedBox(height: 18),
          SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.warmAmber, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                  child: Text(isEdit ? 'Save changes' : 'Add transaction', style: AppTypography.outfitBold.copyWith(fontSize: 14, color: Colors.white)))),
          const SizedBox(height: 8),
          Center(child: Text('\u20b1 amounts are in Philippine pesos \u00b7 splits follow IHateMoney equal-share rules', textAlign: TextAlign.center, style: AppTypography.outfitWhite.copyWith(fontSize: 10, color: AppTheme.petalWhite.withValues(alpha: 0.38))))
        ])));
  }

  Widget _lbl(String t) => Text(t, style: AppTypography.outfitBold.copyWith(fontSize: 11, letterSpacing: 0.4, color: AppTheme.petalWhite.withValues(alpha: 0.7)));
  Widget _tf(TextEditingController c, String h, TextInputType t, List<TextInputFormatter>? f, {String? pref, int maxL = 1}) => TextField(
      controller: c,
      keyboardType: t,
      inputFormatters: f,
      maxLines: maxL,
      style: AppTypography.outfitWhite.copyWith(color: AppTheme.petalWhite, fontSize: 13),
      decoration: InputDecoration(
          hintText: h,
          hintStyle: AppTypography.outfitWhite.copyWith(color: AppTheme.petalWhite.withValues(alpha: 0.32), fontSize: 13),
          prefixText: pref,
          prefixStyle: AppTypography.outfitBold.copyWith(color: AppColors.warmAmber, fontSize: 13),
          filled: true,
          fillColor: AppColors.twilight,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12)));
  Widget _drop<T>({required T value, required List<DropdownMenuItem<T>> items, required ValueChanged<T?> onChanged}) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(color: AppColors.twilight, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.moonlight.withValues(alpha: 0.10))),
      child: DropdownButton<T>(value: value, isExpanded: true, underline: const SizedBox(), dropdownColor: AppColors.twilight, style: AppTypography.outfitWhite.copyWith(color: AppTheme.petalWhite, fontSize: 13), items: items, onChanged: onChanged));
  Widget _tBtn(TransactionType v, String l, IconData ic) {
    final s = type == v;
    return GestureDetector(
        onTap: () => setState(() => type = v),
        child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(color: s ? (v == TransactionType.expense ? Colors.redAccent.withValues(alpha: 0.16) : AppColors.success.withValues(alpha: 0.16)) : Colors.transparent, borderRadius: BorderRadius.circular(9), border: Border.all(color: s ? (v == TransactionType.expense ? Colors.redAccent.withValues(alpha: 0.28) : AppColors.success.withValues(alpha: 0.28)) : Colors.transparent)),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(ic, size: 14, color: s ? (v == TransactionType.expense ? Colors.redAccent : AppColors.success) : AppTheme.petalWhite.withValues(alpha: 0.5)), const SizedBox(width: 6), Text(l, style: AppTypography.outfitBold.copyWith(fontSize: 12, color: s ? (v == TransactionType.expense ? Colors.redAccent : AppColors.success) : AppTheme.petalWhite.withValues(alpha: 0.62)))])));
  }

  Future<void> _pick() async {
    final p = await showDatePicker(context: context, initialDate: date, firstDate: DateTime(2022), lastDate: DateTime(2035), builder: (x, c) => Theme(data: Theme.of(x).copyWith(colorScheme: ColorScheme.dark(primary: AppColors.warmAmber, surface: AppColors.velvet, onSurface: AppTheme.petalWhite)), child: c!));
    if (p != null) setState(() => date = DateTime(p.year, p.month, p.day, date.hour, date.minute));
  }

  Future<void> _save() async {
    final t = titleC.text.trim();
    final a = double.tryParse(amtC.text.trim());
    final n = noteC.text.trim();
    if (t.isEmpty || a == null || a <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Add a title and a valid amount.', style: AppTypography.outfitWhite.copyWith(color: Colors.white)), backgroundColor: AppColors.velvet));
      return;
    }
    final tx = BudgetTransaction(id: widget.existing?.id ?? '', title: t, amount: a, type: type, category: cat, paidBy: paidBy, split: split, date: date, note: n);
    if (widget.existing != null) {
      await BudgetService().update(widget.existing!.id, tx);
    } else {
      await BudgetService().add(tx);
    }
    if (mounted) Navigator.pop(context);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(widget.existing != null ? 'Updated \u201c$t\u201d' : 'Added \u201c$t\u201d \u00b7 ${_fmt(a)}', style: AppTypography.outfitWhite.copyWith(color: Colors.white)), backgroundColor: AppColors.velvet, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
  }
}
