import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/everglow/everglow_background.dart';
import '../../../../shared/widgets/everglow/everglow_scaffold.dart';
import '../../../../shared/widgets/everglow/everglow_feature_header.dart';
import '../../../../shared/widgets/everglow/everglow_icon_button.dart';
import '../../../../shared/widgets/everglow/everglow_empty_state.dart';
import '../../../../shared/widgets/everglow/everglow_segmented_control.dart';
import '../../data/models/budget_transaction.dart';
import '../../data/services/budget_service.dart';

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  int _tabIndex = 0;
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();
    return EverglowScaffold(
      backgroundColor: AppColors.inkDeep,
      glows: [const RadialGlow(color: AppColors.warmAmber, alignment: Alignment(-0.6, -0.8), size: 0.85, opacity: 0.12)],
      showPetals: true,
      body: Column(
              children: [
                EverglowFeatureHeader(
                  title: 'Budget',
                  subtitle: 'Actual × IHateMoney • shared finances',
                  icon: Icons.account_balance_wallet_rounded,
                  hue: AppColors.warmAmber,
                  actions: [
                    EverglowIconButton(
                      icon: Icons.add_rounded,
                      onPressed: () => _showAddDialog(auth),
                      semanticLabel: 'Add transaction',
                      tooltip: 'Add',
                      iconColor: AppColors.blushGold,
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: EverglowSegmentedControl(
                    selectedIndex: _tabIndex,
                    onChanged: (i) => setState(() => _tabIndex = i),
                    activeColor: AppColors.warmAmber,
                    items: const [
                      SegmentItem('Transactions', Icons.receipt_long_rounded),
                      SegmentItem('Budget', Icons.pie_chart_rounded),
                      SegmentItem('Split', Icons.handshake_rounded),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                // Month picker (Actual)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => setState(
                          () =>
                              _month = DateTime(_month.year, _month.month - 1),
                        ),
                        icon: const Icon(
                          Icons.chevron_left_rounded,
                          color: AppColors.blushGold,
                        ),
                      ),
                      Expanded(
                        child: Center(
                          child: Text(
                            '${_monthName(_month.month)} ${_month.year}',
                            style: AppTypography.outfitBold.copyWith(
                              fontSize: 14,
                              color: AppColors.petalWhite,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => setState(
                          () =>
                              _month = DateTime(_month.year, _month.month + 1),
                        ),
                        icon: const Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.blushGold,
                        ),
                      ),
                      TextButton(
                        onPressed: () => setState(
                          () => _month = DateTime(
                            DateTime.now().year,
                            DateTime.now().month,
                          ),
                        ),
                        child: Text(
                          'Today',
                          style: AppTypography.outfitWhite.copyWith(
                            fontSize: 11,
                            color: AppColors.warmAmber,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: _tabIndex == 0
                      ? _TransactionsTab(month: _month)
                      : _tabIndex == 1
                      ? _BudgetTab(month: _month)
                      : _SplitTab(month: _month),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(auth),
        backgroundColor: AppColors.warmAmber,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  String _monthName(int m) => [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ][m - 1];

  void _showAddDialog(AuthService auth) {
    final titleCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    String category = 'Food';
    TransactionType type = TransactionType.expense;
    String paidBy = auth.currentUser ?? 'khentsgdz';
    SplitMode split = SplitMode.equal;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) {
          return AlertDialog(
            backgroundColor: AppTheme.velvet,
            title: Text(
              'Add Transaction',
              style: AppTypography.cormorantBold.copyWith(
                color: AppColors.petalWhite,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleCtrl,
                    style: AppTypography.outfitWhite.copyWith(
                      color: AppColors.petalWhite,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Title — e.g., Dinner at Mesa',
                      hintStyle: AppTypography.outfitWhite.copyWith(
                        color: AppColors.petalWhite.withValues(alpha: 0.4),
                      ),
                      filled: true,
                      fillColor: AppColors.twilight,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: amountCtrl,
                    keyboardType: TextInputType.number,
                    style: AppTypography.outfitWhite.copyWith(
                      color: AppColors.petalWhite,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Amount (PHP)',
                      hintStyle: AppTypography.outfitWhite.copyWith(
                        color: AppColors.petalWhite.withValues(alpha: 0.4),
                      ),
                      filled: true,
                      fillColor: AppColors.twilight,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButton<TransactionType>(
                          value: type,
                          isExpanded: true,
                          dropdownColor: AppColors.twilight,
                          underline: const SizedBox(),
                          style: AppTypography.outfitWhite.copyWith(
                            color: AppColors.petalWhite,
                            fontSize: 12,
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: TransactionType.expense,
                              child: Text('Expense'),
                            ),
                            const DropdownMenuItem(
                              value: TransactionType.income,
                              child: Text('Income'),
                            ),
                          ],
                          onChanged: (v) => setDlg(() => type = v!),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButton<String>(
                          value: category,
                          isExpanded: true,
                          dropdownColor: AppColors.twilight,
                          underline: const SizedBox(),
                          style: AppTypography.outfitWhite.copyWith(
                            color: AppColors.petalWhite,
                            fontSize: 12,
                          ),
                          items: budgetCategories
                              .map(
                                (c) => DropdownMenuItem(
                                  value: c.name,
                                  child: Text('${c.emoji} ${c.name}'),
                                ),
                              )
                              .toList(),
                          onChanged: (v) => setDlg(() => category = v!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButton<String>(
                          value: paidBy,
                          isExpanded: true,
                          dropdownColor: AppColors.twilight,
                          underline: const SizedBox(),
                          style: AppTypography.outfitWhite.copyWith(
                            color: AppColors.petalWhite,
                            fontSize: 12,
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: 'khentsgdz',
                              child: Text('Khent paid'),
                            ),
                            const DropdownMenuItem(
                              value: 'clairjassen',
                              child: Text('Clair paid'),
                            ),
                          ],
                          onChanged: (v) => setDlg(() => paidBy = v!),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButton<SplitMode>(
                          value: split,
                          isExpanded: true,
                          dropdownColor: AppColors.twilight,
                          underline: const SizedBox(),
                          style: AppTypography.outfitWhite.copyWith(
                            color: AppColors.petalWhite,
                            fontSize: 12,
                          ),
                          items: SplitMode.values
                              .map(
                                (s) => DropdownMenuItem(
                                  value: s,
                                  child: Text(s.name),
                                ),
                              )
                              .toList(),
                          onChanged: (v) => setDlg(() => split = v!),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final title = titleCtrl.text.trim();
                  final amt = double.tryParse(amountCtrl.text.trim());
                  if (title.isEmpty || amt == null) return;
                  await BudgetService().add(
                    BudgetTransaction(
                      id: '',
                      title: title,
                      amount: amt,
                      type: type,
                      category: category,
                      paidBy: paidBy,
                      split: split,
                      date: DateTime.now(),
                    ),
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.warmAmber,
                ),
                child: const Text('Add', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TransactionsTab extends StatelessWidget {
  final DateTime month;
  const _TransactionsTab({required this.month});

  @override
  Widget build(BuildContext context) {
    final service = BudgetService();
    return StreamBuilder<List<BudgetTransaction>>(
      stream: service.watchMonth(month),
      builder: (context, snap) {
        final txs = snap.data ?? [];
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              color: AppColors.deepRose,
              strokeWidth: 2,
            ),
          );
        }
        if (txs.isEmpty) {
          return const EverglowEmptyState(
            icon: Icons.receipt_long_rounded,
            title: 'No transactions',
            subtitle: 'Add your first expense — IHateMoney will split it',
            ctaLabel: null,
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          itemCount: txs.length,
          itemBuilder: (context, idx) {
            final t = txs[idx];
            final isExpense = t.type == TransactionType.expense;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.moonlight.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isExpense
                      ? Colors.redAccent.withValues(alpha: 0.15)
                      : AppColors.success.withValues(alpha: 0.15),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: (isExpense ? Colors.redAccent : AppColors.success)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        _catEmoji(t.category),
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.title,
                          style: AppTypography.outfitBold.copyWith(
                            fontSize: 12,
                            color: AppColors.petalWhite,
                          ),
                        ),
                        Text(
                          '${t.category} • paid by ${t.paidBy} • ${t.date.month}/${t.date.day} • split ${t.split.name}',
                          style: AppTypography.outfitWhite.copyWith(
                            fontSize: 10,
                            color: AppColors.petalWhite.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${isExpense ? '-' : '+'}₱${t.amount.toStringAsFixed(0)}',
                    style: AppTypography.outfitBold.copyWith(
                      fontSize: 13,
                      color: isExpense ? Colors.redAccent : AppColors.success,
                    ),
                  ),
                  IconButton(
                    onPressed: () => service.delete(t.id),
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      size: 16,
                      color: AppColors.petalWhite.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _catEmoji(String cat) {
    final c = budgetCategories.where((e) => e.name == cat).isEmpty
        ? budgetCategories.last
        : budgetCategories.firstWhere((e) => e.name == cat);
    return c.emoji;
  }
}

class _BudgetTab extends StatelessWidget {
  final DateTime month;
  const _BudgetTab({required this.month});

  @override
  Widget build(BuildContext context) {
    final service = BudgetService();
    return StreamBuilder<List<BudgetTransaction>>(
      stream: service.watchMonth(month),
      builder: (context, snap) {
        final txs = snap.data ?? [];
        final byCat = service.byCategory(txs);
        final totalExpense = byCat.values.fold(0.0, (a, b) => a + b);
        final totalIncome = txs
            .where((t) => t.type == TransactionType.income)
            .fold(0.0, (a, b) => a + b.amount);
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.warmAmber.withValues(alpha: 0.18),
                    AppColors.deepRose.withValues(alpha: 0.12),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.warmAmber.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Actual • Envelope',
                    style: AppTypography.outfitBold.copyWith(
                      fontSize: 12,
                      color: AppColors.warmAmber,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildMoney(
                          'Income',
                          totalIncome,
                          AppColors.success,
                        ),
                      ),
                      Container(width: 1, height: 36, color: AppColors.border),
                      Expanded(
                        child: _buildMoney(
                          'Spent',
                          totalExpense,
                          Colors.redAccent,
                        ),
                      ),
                      Container(width: 1, height: 36, color: AppColors.border),
                      Expanded(
                        child: _buildMoney(
                          'Balance',
                          totalIncome - totalExpense,
                          totalIncome - totalExpense >= 0
                              ? AppColors.success
                              : Colors.redAccent,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (byCat.isEmpty)
              Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'No expenses this month',
                  style: AppTypography.outfitWhite.copyWith(
                    color: AppColors.petalWhite.withValues(alpha: 0.6),
                  ),
                  textAlign: TextAlign.center,
                ),
              )
            else
              ...byCat.entries.map((e) {
                final pct = totalExpense == 0 ? 0.0 : e.value / totalExpense;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.moonlight.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            _catEmoji(e.key),
                            style: const TextStyle(fontSize: 14),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              e.key,
                              style: AppTypography.outfitBold.copyWith(
                                fontSize: 12,
                                color: AppColors.petalWhite,
                              ),
                            ),
                          ),
                          Text(
                            '₱${e.value.toStringAsFixed(0)}',
                            style: AppTypography.outfitBold.copyWith(
                              fontSize: 12,
                              color: AppColors.petalWhite,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${(pct * 100).toStringAsFixed(0)}%',
                            style: AppTypography.outfitWhite.copyWith(
                              fontSize: 10,
                              color: AppColors.petalWhite.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: pct,
                          minHeight: 6,
                          backgroundColor: AppColors.moonlight.withValues(
                            alpha: 0.12,
                          ),
                          valueColor: AlwaysStoppedAnimation(_catColor(e.key)),
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        );
      },
    );
  }

  Widget _buildMoney(String label, double amount, Color color) => Column(
    children: [
      Text(
        label,
        style: AppTypography.outfitWhite.copyWith(
          fontSize: 10,
          color: AppColors.petalWhite.withValues(alpha: 0.6),
        ),
      ),
      const SizedBox(height: 4),
      Text(
        '₱${amount.toStringAsFixed(0)}',
        style: AppTypography.outfitBold.copyWith(fontSize: 14, color: color),
      ),
    ],
  );

  String _catEmoji(String cat) => budgetCategories
      .firstWhere((c) => c.name == cat, orElse: () => budgetCategories.last)
      .emoji;
  Color _catColor(String cat) {
    final hex = budgetCategories
        .firstWhere((c) => c.name == cat, orElse: () => budgetCategories.last)
        .colorHex;
    return Color(int.parse(hex.replaceAll('#', '0xFF')));
  }
}

class _SplitTab extends StatelessWidget {
  final DateTime month;
  const _SplitTab({required this.month});

  @override
  Widget build(BuildContext context) {
    final service = BudgetService();
    return StreamBuilder<List<BudgetTransaction>>(
      stream: service.watchMonth(month),
      builder: (context, snap) {
        final txs = snap.data ?? [];
        final owes = service.computeOwes(txs);
        final khentOwes = owes['khentsgdz'] ?? 0;
        final clairOwes = owes['clairjassen'] ?? 0;
        final khentPaid = owes['khentPaid'] ?? 0;
        final clairPaid = owes['clairPaid'] ?? 0;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.inkDeep.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.auroraTeal.withValues(alpha: 0.15),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.handshake_rounded,
                        size: 16,
                        color: AppColors.auroraTeal,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'IHateMoney • Who owes who',
                        style: AppTypography.outfitBold.copyWith(
                          fontSize: 13,
                          color: AppColors.petalWhite,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildOweCard(
                          'Khent paid',
                          khentPaid,
                          AppColors.auroraTeal,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildOweCard(
                          'Clair paid',
                          clairPaid,
                          AppColors.blushGold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (khentOwes.abs() < 1 && clairOwes.abs() < 1)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.check_circle_rounded,
                            size: 16,
                            color: AppColors.success,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'All settled — no one owes!',
                            style: AppTypography.outfitBold.copyWith(
                              fontSize: 12,
                              color: AppColors.success,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (khentOwes > 1)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Khent owes Clair ₱${khentOwes.toStringAsFixed(0)}',
                        style: AppTypography.outfitBold.copyWith(
                          fontSize: 13,
                          color: Colors.redAccent,
                        ),
                      ),
                    ),
                  if (clairOwes > 1)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Clair owes Khent ₱${clairOwes.toStringAsFixed(0)}',
                        style: AppTypography.outfitBold.copyWith(
                          fontSize: 13,
                          color: Colors.redAccent,
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    'Equal split unless specified — matches IHateMoney & facto logic',
                    style: AppTypography.outfitWhite.copyWith(
                      fontSize: 10,
                      color: AppColors.petalWhite.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'How splits work',
              style: AppTypography.outfitBold.copyWith(
                fontSize: 12,
                color: AppColors.petalWhite,
              ),
            ),
            const SizedBox(height: 8),
            _buildSplitExplainer(),
          ],
        );
      },
    );
  }

  Widget _buildOweCard(String label, double amount, Color hue) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: hue.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      children: [
        Text(
          label,
          style: AppTypography.outfitWhite.copyWith(
            fontSize: 10,
            color: AppColors.petalWhite.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '₱${amount.toStringAsFixed(0)}',
          style: AppTypography.outfitBold.copyWith(fontSize: 16, color: hue),
        ),
      ],
    ),
  );

  Widget _buildSplitExplainer() => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.twilight,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '• Equal: 50/50 split',
          style: AppTypography.outfitWhite.copyWith(
            fontSize: 11,
            color: AppColors.petalWhite.withValues(alpha: 0.7),
          ),
        ),
        Text(
          '• Khent / Clair: one pays full',
          style: AppTypography.outfitWhite.copyWith(
            fontSize: 11,
            color: AppColors.petalWhite.withValues(alpha: 0.7),
          ),
        ),
        Text(
          '• Custom: ratio via Firestore customSplit map',
          style: AppTypography.outfitWhite.copyWith(
            fontSize: 11,
            color: AppColors.petalWhite.withValues(alpha: 0.7),
          ),
        ),
      ],
    ),
  );
}
