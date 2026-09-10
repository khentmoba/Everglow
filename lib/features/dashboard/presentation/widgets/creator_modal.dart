import 'package:flutter/material.dart';

import '../../data/services/creator_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import 'creator/creator_letters_tab.dart';
import 'creator/creator_memories_tab.dart';
import 'creator/creator_surprises_tab.dart';
import 'creator/creator_system_tab.dart';

/// Creator Studio — Khent's private workshop for Clair.
///
/// Four focused tabs replacing the legacy CreatorModal:
/// * Letters — compose + Letterbox vault with unlock scheduling
/// * Memories — multi-photo milestones with live preview + history
/// * Surprises — Guardian whispers, love bursts, teaser countdowns,
///   date-night spotlight
/// * System — backend health, partner sync, maintenance tools
///
/// The widget stays build-safe without Firebase or providers so the
/// regression test can pump it in isolation; each tab degrades to an
/// empty state when its stream cannot attach.
class CreatorModal extends StatefulWidget {
  final CreatorService? creatorService;

  const CreatorModal({super.key, this.creatorService});

  @override
  State<CreatorModal> createState() => _CreatorModalState();
}

class _CreatorModalState extends State<CreatorModal>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late final CreatorService _creatorService;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _creatorService = widget.creatorService ?? CreatorService();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.sizeOf(context).height * 0.85,
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      decoration: BoxDecoration(
        color: AppColors.panelGlass,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.moonlight.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Creator Studio ✨',
            style: AppTypography.outfitHeading.copyWith(
              fontSize: 17,
              color: AppColors.petalWhite,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Khent’s private workshop for Clair',
            style: AppTypography.outfitWhite.copyWith(
              fontSize: 12,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 8),
          TabBar(
            controller: _tabController,
            dividerColor: Colors.transparent,
            indicatorColor: AppColors.blushGold,
            indicatorSize: TabBarIndicatorSize.label,
            labelColor: AppColors.petalWhite,
            unselectedLabelColor: AppColors.textMuted,
            labelStyle: AppTypography.outfitBold.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              letterSpacing: 0.2,
            ),
            tabs: const [
              Tab(text: 'Letters'),
              Tab(text: 'Memories'),
              Tab(text: 'Surprises'),
              Tab(text: 'System'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                CreatorLettersTab(creatorService: _creatorService),
                CreatorMemoriesTab(creatorService: _creatorService),
                CreatorSurprisesTab(creatorService: _creatorService),
                CreatorSystemTab(creatorService: _creatorService),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
