import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../features/budget/data/services/budget_service.dart';

class BudgetPreview extends StatelessWidget {
  const BudgetPreview({super.key});

  @override
  Widget build(BuildContext context) {
    final service = BudgetService();
    final now = DateTime.now();
    return StreamBuilder(
      stream: service.watchMonth(DateTime(now.year, now.month)),
      builder: (context, snap) {
        final txs = snap.data ?? [];
        final byCat = service.byCategory(txs);
        final spent = byCat.values.fold(0.0, (a, b) => a + b);
        final owes = service.computeOwes(txs);
        final owesStr = (owes['khentsgdz'] ?? 0).abs() < 1 && (owes['clairjassen'] ?? 0).abs() < 1 ? 'All settled' : (owes['khentsgdz']! > 0 ? 'Khent owes ₱${owes['khentsgdz']!.toStringAsFixed(0)}' : 'Clair owes ₱${owes['clairjassen']!.toStringAsFixed(0)}');
        return GestureDetector(
          onTap: () => context.push('/budget'),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.moonlight.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.warmAmber.withValues(alpha: 0.18))),
            child: Row(
              children: [
                Container(width: 44, height: 44, decoration: BoxDecoration(color: AppColors.warmAmber.withValues(alpha: 0.15), shape: BoxShape.circle), child: Icon(Icons.account_balance_wallet_rounded, color: AppColors.warmAmber, size: 20)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Budget', style: AppTypography.outfitBold.copyWith(fontSize: 14, color: AppColors.petalWhite)),
                      const SizedBox(height: 4),
                      Text(txs.isEmpty ? 'No transactions this month' : '₱${spent.toStringAsFixed(0)} spent • $owesStr', style: AppTypography.outfitWhite.copyWith(fontSize: 11, color: AppColors.petalWhite.withValues(alpha: 0.6))),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: AppColors.warmAmber, size: 20),
              ],
            ),
          ),
        );
      },
    );
  }
}
