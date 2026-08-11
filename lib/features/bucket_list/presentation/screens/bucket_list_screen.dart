import 'package:flutter/material.dart';
import 'package:provider/provider.dart';import 'package:go_router/go_router.dart';
import 'package:everglow/core/theme/app_theme.dart';
import 'package:everglow/shared/widgets/gamified_background.dart';
import 'package:everglow/services/auth_service.dart';
import 'package:everglow/shared/widgets/everglow/everglow_error_state.dart';
import 'package:everglow/shared/widgets/everglow/everglow_empty_state.dart';
import 'package:everglow/shared/widgets/everglow/everglow_skeleton.dart';
import '../../data/models/bucket_item.dart';
import '../../data/services/bucket_list_service.dart';
import '../widgets/bucket_item_card.dart';
import '../widgets/add_bucket_item_dialog.dart';
import 'package:everglow/core/theme/app_typography.dart';

class BucketListScreen extends StatefulWidget {
  const BucketListScreen({super.key});

  @override
  State<BucketListScreen> createState() => _BucketListScreenState();
}

class _BucketListScreenState extends State<BucketListScreen> {
  BucketStatus? _filter; // null = all

  @override
  Widget build(BuildContext context) {
    final service = BucketListService();
    final auth = context.read<AuthService>();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GamifiedBackground(
        child: SafeArea(
          child: Column(
            children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => context.go('/dashboard'),
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: AppTheme.roseQuartz,
                      size: 20,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Our Bucket List',
                    style: AppTypography.cormorantBold.copyWith(fontSize: 22, letterSpacing: 1.5),
                  ),
                  const Spacer(),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Progress bar
            _buildProgressHeader(service),
            const SizedBox(height: 12),

            // Filter chips
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _buildFilterChip(null, 'All'),
                  const SizedBox(width: 8),
                  _buildFilterChip(BucketStatus.wish, 'Wishes'),
                  const SizedBox(width: 8),
                  _buildFilterChip(BucketStatus.planned, 'Planned'),
                  const SizedBox(width: 8),
                  _buildFilterChip(BucketStatus.completed, 'Done'),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // List
            Expanded(
              child: StreamBuilder<List<BucketItem>>(
                stream: _filter != null
                    ? service.watchByStatus(_filter!)
                    : service.watchAll(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return EverglowErrorState(
                      message: 'Could not load bucket list',
                      onRetry: () => setState(() {}),
                      icon: Icons.cloud_off_outlined,
                    );
                  }

                  if (!snapshot.hasData) {
                    return const EverglowSkeleton(
                      width: double.infinity,
                      height: 80,
                      radius: 16,
                    );
                  }

                  final items = snapshot.data!;
                  if (items.isEmpty) {
                    return EverglowEmptyState(
                      icon: Icons.auto_awesome,
                      title: _filter == null
                          ? 'Your bucket list is empty'
                          : 'No ${_filter!.displayName.toLowerCase()} items yet',
                      subtitle: _filter == null ? 'Add your first dream together!' : null,
                      ctaLabel: _filter == null ? 'Add Dream' : null,
                      onCta: _filter == null ? () => _showAddDialog(context, auth) : null,
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      return BucketItemCard(
                        item: items[index],
                        currentUsername: auth.currentUser ?? '',
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(context, auth),
        backgroundColor: AppTheme.deepRose,
        foregroundColor: AppTheme.petalWhite,
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  Widget _buildProgressHeader(BucketListService service) {
    return StreamBuilder<List<BucketItem>>(
      stream: service.watchAll(),
      builder: (context, snapshot) {
        final all = snapshot.data ?? [];
        final completed = all.where((i) => i.status == BucketStatus.completed).length;
        final total = all.length;
        final progress = total > 0 ? completed / total : 0.0;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.moonlight.withValues(alpha: AppTheme.glassOpacity),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppTheme.blushGold.withValues(alpha: 0.15),
              ),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 48,
                  height: 48,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 4,
                        backgroundColor: AppTheme.petalWhite.withValues(alpha: 0.1),
                        valueColor: AlwaysStoppedAnimation(AppTheme.blushGold),
                      ),
                      Text(
                        '$completed',
                        style: AppTypography.outfitWhite.copyWith(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.blushGold),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$completed of $total dreams fulfilled ✨',
                        style: AppTypography.outfitBold.copyWith(fontSize: 14, color: AppTheme.petalWhite),
                      ),
                      if (total > 0)
                        Text(
                          '${(progress * 100).round()}% complete',
                          style: AppTypography.outfitWhite.copyWith(fontSize: 11, color: AppTheme.petalWhite.withValues(alpha: 0.6)),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilterChip(BucketStatus? status, String label) {
    final isSelected = _filter == status;
    return GestureDetector(
      onTap: () => setState(() => _filter = status),
      child: Semantics(
        button: true,
        label: 'Filter by $label',
        toggled: isSelected,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.deepRose.withValues(alpha: 0.3)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? AppTheme.blushGold
                  : AppTheme.blushGold.withValues(alpha: 0.15),
            ),
          ),
          child: Text(
            label,
            style: AppTypography.outfitWhite.copyWith(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.w500, color: isSelected
                  ? AppTheme.blushGold
                  : AppTheme.petalWhite.withValues(alpha: 0.6)),
          ),
        ),
      ),
    );
  }

  void _showAddDialog(BuildContext context, AuthService auth) {
    showDialog(
      context: context,
      builder: (context) => AddBucketItemDialog(
        createdBy: auth.currentUser ?? 'unknown',
      ),
    );
  }
}
