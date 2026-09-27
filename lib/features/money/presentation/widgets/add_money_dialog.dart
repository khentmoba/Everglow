import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/everglow/everglow_button.dart';
import '../../../../shared/widgets/everglow/everglow_segmented_control.dart';
import '../../data/models/money_entry.dart';

/// Quick-add: amount + category + note, done in seconds.
/// Returns the filled entry (minus id/author/timestamp) or null.
Future<({MoneyType type, double amount, String category, String note})?>
showAddMoneyDialog(BuildContext context) {
  return showDialog<
      ({MoneyType type, double amount, String category, String note})>(
    context: context,
    builder: (_) => const _AddMoneyDialog(),
  );
}

class _AddMoneyDialog extends StatefulWidget {
  const _AddMoneyDialog();

  @override
  State<_AddMoneyDialog> createState() => _AddMoneyDialogState();
}

class _AddMoneyDialogState extends State<_AddMoneyDialog> {
  MoneyType _type = MoneyType.expense;
  final _amount = TextEditingController();
  final _note = TextEditingController();
  String _category = 'Food';

  List<String> get _categories =>
      _type == MoneyType.expense ? MoneyCategories.expense : MoneyCategories.income;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  void _save() {
    final amount = double.tryParse(_amount.text.replaceAll(',', '')) ?? 0;
    if (amount <= 0) return;
    Navigator.of(context).pop((
      type: _type,
      amount: amount,
      category: _category,
      note: _note.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.velvet,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusXl),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Add money',
              style: AppTypography.cormorantBold.copyWith(
                fontSize: 24,
                color: AppColors.petalWhite,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'one shared wallet for us',
              style: AppTypography.bodySmall().copyWith(
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 16),
            EverglowSegmentedControl(
              selectedIndex: _type == MoneyType.expense ? 0 : 1,
              onChanged: (i) => setState(() {
                _type = i == 0 ? MoneyType.expense : MoneyType.income;
                _category = _categories.first;
              }),
              items: const [
                SegmentItem('Spent', Icons.arrow_upward_rounded),
                SegmentItem('Got', Icons.arrow_downward_rounded),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              autofocus: true,
              onSubmitted: (_) => _save(),
              style: AppTypography.outfitWhite.copyWith(fontSize: 28),
              decoration: InputDecoration(
                prefixText: '₱ ',
                prefixStyle: AppTypography.outfitWhite.copyWith(
                  fontSize: 28,
                  color: AppColors.blushGold,
                ),
                hintText: '0',
                hintStyle: AppTypography.outfitWhite.copyWith(
                  fontSize: 28,
                  color: AppColors.textDisabled,
                ),
                filled: true,
                fillColor: AppColors.inkDeep.withValues(alpha: 0.5),
                border: OutlineInputBorder(
                  borderRadius: AppRadius.radiusLg,
                  borderSide: BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: AppRadius.radiusLg,
                  borderSide: BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: AppRadius.radiusLg,
                  borderSide: const BorderSide(color: AppColors.blushGold),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in _categories)
                  ChoiceChip(
                    label: Text('${MoneyCategories.iconFor(c)} $c'),
                    selected: _category == c,
                    onSelected: (_) => setState(() => _category = c),
                    selectedColor: AppColors.deepRose.withValues(alpha: 0.35),
                    backgroundColor:
                        AppColors.moonlight.withValues(alpha: 0.08),
                    labelStyle: AppTypography.bodySmall().copyWith(
                      color: _category == c
                          ? AppColors.petalWhite
                          : AppColors.textMedium,
                    ),
                    side: BorderSide(
                      color: _category == c
                          ? AppColors.auroraRose
                          : AppColors.border,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _note,
              textCapitalization: TextCapitalization.sentences,
              onSubmitted: (_) => _save(),
              style: AppTypography.bodyMedium(),
              decoration: InputDecoration(
                hintText: 'Note (optional) — e.g. milk tea with Clair',
                hintStyle: AppTypography.bodySmall().copyWith(
                  color: AppColors.textDisabled,
                ),
                filled: true,
                fillColor: AppColors.inkDeep.withValues(alpha: 0.5),
                border: OutlineInputBorder(
                  borderRadius: AppRadius.radiusLg,
                  borderSide: BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: AppRadius.radiusLg,
                  borderSide: BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: AppRadius.radiusLg,
                  borderSide: const BorderSide(color: AppColors.blushGold),
                ),
              ),
            ),
            const SizedBox(height: 18),
            EverglowButton(
              label: _type == MoneyType.expense
                  ? 'Log spending'
                  : 'Log income',
              icon: Icons.check_rounded,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}

/// Small dialog to set a monthly cap for one category.
Future<double?> showSetBudgetDialog(
  BuildContext context,
  String category, {
  double current = 0,
}) {
  final controller = TextEditingController(
    text: current > 0 ? current.toStringAsFixed(0) : '',
  );
  return showDialog<double>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: AppColors.velvet,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusXl),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${MoneyCategories.iconFor(category)} $category budget',
              style: AppTypography.cormorantBold.copyWith(
                fontSize: 22,
                color: AppColors.petalWhite,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'monthly cap — 0 removes it',
              style: AppTypography.bodySmall().copyWith(
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              autofocus: true,
              onSubmitted: (_) => Navigator.of(ctx).pop(
                double.tryParse(controller.text.replaceAll(',', '')) ?? 0,
              ),
              style: AppTypography.outfitWhite.copyWith(fontSize: 24),
              decoration: InputDecoration(
                prefixText: '₱ ',
                prefixStyle: AppTypography.outfitWhite.copyWith(
                  fontSize: 24,
                  color: AppColors.blushGold,
                ),
                hintText: '0',
                filled: true,
                fillColor: AppColors.inkDeep.withValues(alpha: 0.5),
                border: OutlineInputBorder(
                  borderRadius: AppRadius.radiusLg,
                  borderSide: BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: AppRadius.radiusLg,
                  borderSide: BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: AppRadius.radiusLg,
                  borderSide: const BorderSide(color: AppColors.blushGold),
                ),
              ),
            ),
            const SizedBox(height: 16),
            EverglowButton(
              label: 'Save budget',
              icon: Icons.savings_rounded,
              onPressed: () => Navigator.of(ctx).pop(
                double.tryParse(controller.text.replaceAll(',', '')) ?? 0,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
