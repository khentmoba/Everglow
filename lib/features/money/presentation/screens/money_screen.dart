import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/everglow/everglow_background.dart';
import '../../../../shared/widgets/everglow/everglow_empty_state.dart';
import '../../../../shared/widgets/everglow/everglow_feature_header.dart';
import '../../../../shared/widgets/everglow/everglow_icon_button.dart';
import '../../../../shared/widgets/everglow/everglow_scaffold.dart';
import '../../../../shared/widgets/everglow/everglow_section_header.dart';
import '../../../../shared/widgets/everglow/everglow_stream_view.dart';
import '../../data/models/money_entry.dart';
import '../../data/services/money_service.dart';
import '../widgets/add_money_dialog.dart';

/// Our Money — one shared peso wallet with monthly budgets.
class MoneyScreen extends StatelessWidget {
  const MoneyScreen({super.key});

  Future<void> _quickAdd(BuildContext context) async {
    final result = await showAddMoneyDialog(context);
    if (result == null || !context.mounted) return;
    final author = context.read<AuthService>().currentUser ?? '';
    await MoneyService().add(
      MoneyEntry(
        id: '',
        type: result.type,
        amount: result.amount,
        category: result.category,
        note: result.note,
        author: author,
        createdAt: DateTime.now(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return EverglowScaffold(
      backgroundColor: AppColors.inkDeep,
      glows: const [
        RadialGlow(
          color: AppColors.deepRose,
          alignment: Alignment(-0.8, -0.9),
          size: 0.7,
          opacity: 0.14,
        ),
        RadialGlow(
          color: AppColors.auroraGold,
          alignment: Alignment(0.9, 0.9),
          size: 0.65,
          opacity: 0.07,
        ),
      ],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _quickAdd(context),
        backgroundColor: AppColors.deepRose,
        foregroundColor: AppColors.petalWhite,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add'),
      ),
      body: Column(
        children: [
          EverglowFeatureHeader(
            title: 'Our Money',
            subtitle: 'one shared wallet',
            icon: Icons.savings_rounded,
            hue: AppColors.auroraGold,
            actions: [
              EverglowIconButton(
                icon: Icons.add_rounded,
                onPressed: () => _quickAdd(context),
                semanticLabel: 'Add money entry',
                tooltip: 'Add',
                iconColor: AppColors.blushGold,
              ),
            ],
          ),
          Expanded(
            child: EverglowStreamView<List<MoneyEntry>>(
              stream: MoneyService().watchRecent(),
              streamLabel: 'money-recent',
              errorMessage: 'Could not load our money',
              isEmpty: (_) => false, // empty handled inside (summary shows ₱0)
              builder: (context, entries) =>
                  _MoneyBody(entries: entries, onAdd: () => _quickAdd(context)),
            ),
          ),
        ],
      ),
    );
  }
}

class _MoneyBody extends StatelessWidget {
  final List<MoneyEntry> entries;
  final VoidCallback onAdd;

  const _MoneyBody({required this.entries, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final total = summarizeMonth(entries, now);
    final spent = spentByCategory(entries, now);
    final monthEntries = entries
        .where((e) => e.createdAt.year == now.year && e.createdAt.month == now.month)
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
      children: [
        _SummaryCard(total: total),
        const SizedBox(height: 18),
        const EverglowSectionHeader(
          label: 'Budgets',
          icon: Icons.pie_chart_outline_rounded,
          hue: AppColors.auroraTeal,
        ),
        const SizedBox(height: 10),
        EverglowStreamView<List<BudgetLimit>>(
          stream: MoneyService().watchLimits(),
          streamLabel: 'money-limits',
          errorMessage: 'Could not load budgets',
          isEmpty: (limits) => limits.isEmpty,
          emptyView: _SetBudgetHint(onAdd: onAdd),
          builder: (context, limits) => Column(
            children: [
              for (final l in limits)
                _BudgetBar(
                  limit: l,
                  spent: spent[l.category] ?? 0,
                  onEdit: () => _editBudget(context, l),
                ),
              _AddBudgetTile(
                existing: limits.map((l) => l.category).toSet(),
                onPick: (c) => _editBudget(context, BudgetLimit(category: c, amount: 0)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const EverglowSectionHeader(
          label: 'This month',
          icon: Icons.receipt_long_rounded,
          hue: AppColors.blushGold,
        ),
        const SizedBox(height: 10),
        if (monthEntries.isEmpty)
          EverglowEmptyState(
            icon: Icons.savings_outlined,
            title: 'Nothing yet this month',
            subtitle: 'Tap + to log your first peso together.',
            ctaLabel: 'Add money',
            onCta: onAdd,
          )
        else
          for (final e in monthEntries) _MoneyRow(entry: e),
      ],
    );
  }

  Future<void> _editBudget(BuildContext context, BudgetLimit l) async {
    final amount = await showSetBudgetDialog(
      context,
      l.category,
      current: l.amount,
    );
    if (amount == null) return;
    if (amount <= 0) {
      await MoneyService().removeLimit(l.category);
    } else {
      await MoneyService().setLimit(l.category, amount);
    }
  }
}

class _SummaryCard extends StatelessWidget {
  final MonthlyTotal total;
  const _SummaryCard({required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.panelGlass,
        borderRadius: AppRadius.radiusXl,
        border: Border.all(
          color: AppColors.moonlight.withValues(alpha: 0.11),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Left this month',
            style: AppTypography.bodySmall().copyWith(
              color: AppColors.textMuted,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            formatPeso(total.balance),
            style: AppTypography.cormorantBlack.copyWith(
              fontSize: 40,
              height: 1.0,
              color: total.balance < 0
                  ? AppColors.error
                  : AppColors.blushGold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  label: 'Got',
                  value: formatPeso(total.income),
                  color: AppColors.success,
                  icon: Icons.arrow_downward_rounded,
                ),
              ),
              Container(
                width: 1,
                height: 36,
                color: AppColors.divider,
              ),
              Expanded(
                child: _MiniStat(
                  label: 'Spent',
                  value: formatPeso(total.expense),
                  color: AppColors.auroraRose,
                  icon: Icons.arrow_upward_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: AppTypography.bodySmall().copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: AppTypography.outfitBold.copyWith(
              fontSize: 17,
              color: AppColors.petalWhite,
            ),
          ),
        ],
      ),
    );
  }
}

class _BudgetBar extends StatelessWidget {
  final BudgetLimit limit;
  final double spent;
  final VoidCallback onEdit;
  const _BudgetBar({
    required this.limit,
    required this.spent,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final pct = limit.amount <= 0 ? 0.0 : (spent / limit.amount).clamp(0.0, 1.0);
    final over = limit.amount > 0 && spent > limit.amount;
    final color = over ? AppColors.error : AppColors.auroraTeal;
    return GestureDetector(
      onTap: onEdit,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.moonlight.withValues(alpha: 0.05),
          borderRadius: AppRadius.radiusLg,
          border: Border.all(
            color: AppColors.moonlight.withValues(alpha: 0.10),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  MoneyCategories.iconFor(limit.category),
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    limit.category,
                    style: AppTypography.bodyMedium().copyWith(
                      color: AppColors.petalWhite,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  '${formatPeso(spent)} / ${formatPeso(limit.amount)}',
                  style: AppTypography.bodySmall().copyWith(
                    color: over ? AppColors.error : AppColors.textMuted,
                    fontWeight: over ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 6,
                backgroundColor: AppColors.moonlight.withValues(alpha: 0.10),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SetBudgetHint extends StatelessWidget {
  final VoidCallback onAdd;
  const _SetBudgetHint({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _pickCategory(context),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.auroraTeal.withValues(alpha: 0.07),
          borderRadius: AppRadius.radiusLg,
          border: Border.all(
            color: AppColors.auroraTeal.withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.pie_chart_outline_rounded,
              color: AppColors.auroraTeal,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Set a monthly cap — e.g. Food ₱8,000',
                style: AppTypography.bodySmall().copyWith(
                  color: AppColors.textMedium,
                ),
              ),
            ),
            const Icon(
              Icons.add_rounded,
              color: AppColors.auroraTeal,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickCategory(BuildContext context) async {
    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        backgroundColor: AppColors.velvet,
        title: Text(
          'Budget for…',
          style: AppTypography.cormorantBold.copyWith(
            color: AppColors.petalWhite,
          ),
        ),
        children: [
          for (final c in MoneyCategories.expense)
            SimpleDialogOption(
              onPressed: () => Navigator.of(ctx).pop(c),
              child: Text(
                '${MoneyCategories.iconFor(c)} $c',
                style: AppTypography.bodyMedium().copyWith(
                  color: AppColors.petalWhite,
                ),
              ),
            ),
        ],
      ),
    );
    if (picked == null || !context.mounted) return;
    final amount = await showSetBudgetDialog(context, picked);
    if (amount == null || amount <= 0) return;
    await MoneyService().setLimit(picked, amount);
  }
}

class _AddBudgetTile extends StatelessWidget {
  final Set<String> existing;
  final ValueChanged<String> onPick;
  const _AddBudgetTile({required this.existing, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final remaining =
        MoneyCategories.expense.where((c) => !existing.contains(c)).toList();
    if (remaining.isEmpty) return const SizedBox.shrink();
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: () async {
          final picked = await showDialog<String>(
            context: context,
            builder: (ctx) => SimpleDialog(
              backgroundColor: AppColors.velvet,
              title: Text(
                'Budget for…',
                style: AppTypography.cormorantBold.copyWith(
                  color: AppColors.petalWhite,
                ),
              ),
              children: [
                for (final c in remaining)
                  SimpleDialogOption(
                    onPressed: () => Navigator.of(ctx).pop(c),
                    child: Text(
                      '${MoneyCategories.iconFor(c)} $c',
                      style: AppTypography.bodyMedium().copyWith(
                        color: AppColors.petalWhite,
                      ),
                    ),
                  ),
              ],
            ),
          );
          if (picked != null) onPick(picked);
        },
        icon: const Icon(
          Icons.add_rounded,
          size: 16,
          color: AppColors.auroraTeal,
        ),
        label: Text(
          'Add budget',
          style: AppTypography.bodySmall().copyWith(
            color: AppColors.auroraTeal,
          ),
        ),
      ),
    );
  }
}

class _MoneyRow extends StatelessWidget {
  final MoneyEntry entry;
  const _MoneyRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    final isIncome = entry.type == MoneyType.income;
    final color = isIncome ? AppColors.success : AppColors.petalWhite;
    return Dismissible(
      key: ValueKey(entry.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.15),
          borderRadius: AppRadius.radiusLg,
        ),
        child: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
      ),
      confirmDismiss: (_) async {
        final yes = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.velvet,
            title: Text(
              'Remove this?',
              style: AppTypography.cormorantBold.copyWith(
                color: AppColors.petalWhite,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Keep'),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text(
                  'Remove',
                  style: TextStyle(color: AppColors.error),
                ),
              ),
            ],
          ),
        );
        if (yes == true) await MoneyService().delete(entry.id);
        return false; // stream rebuilds the list; no local removal needed
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.moonlight.withValues(alpha: 0.05),
          borderRadius: AppRadius.radiusLg,
          border: Border.all(
            color: AppColors.moonlight.withValues(alpha: 0.10),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (isIncome ? AppColors.success : AppColors.auroraRose)
                    .withValues(alpha: 0.12),
              ),
              alignment: Alignment.center,
              child: Text(
                MoneyCategories.iconFor(entry.category),
                style: const TextStyle(fontSize: 17),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.note.isEmpty ? entry.category : entry.note,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodyMedium().copyWith(
                      color: AppColors.petalWhite,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    '${entry.category} · ${_authorLabel(entry.author)}',
                    style: AppTypography.bodySmall().copyWith(
                      color: AppColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '${isIncome ? '+' : '−'}${formatPeso(entry.amount)}',
              style: AppTypography.outfitBold.copyWith(
                fontSize: 15,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _authorLabel(String author) {
    final a = author.toLowerCase();
    if (a == 'clairjassen' || a == 'clair') return 'Clair';
    if (a == 'khentsgdz' || a == 'khent') return 'Khent';
    if (a.isEmpty) return 'us';
    return a;
  }
}
