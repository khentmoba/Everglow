part of 'dashboard_screen.dart';

/// Display sections of the dashboard screen, split out of
/// [dashboard_screen.dart] to keep the state lifecycle readable.
/// Same library, so all private state stays reachable.
extension _DashboardScreenSections on _DashboardScreenState {
  Widget _buildHeader(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final titleSize = width < 400 ? 38.0 : 48.0;
    return Center(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.moonlight.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: AppColors.moonlight.withValues(alpha: 0.10),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.auroraRose,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.auroraRose.withValues(alpha: 0.6),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'EST.  FEBRUARY 14, 2026  —  KHENT  &  CLAIR',
                  style: AppTypography.outfitHeading.copyWith(
                    fontSize: 9.5,
                    letterSpacing: 2.0,
                    color: AppColors.blushGold.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          BreathingEmblem(
            child: Container(
              width: 108,
              height: 108,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.moonlight.withValues(alpha: 0.18),
                    AppColors.deepRose.withValues(alpha: 0.12),
                    AppColors.inkDeep.withValues(alpha: 0.9),
                  ],
                  stops: const [0.0, 0.55, 1.0],
                ),
                border: Border.all(
                  color: AppColors.moonlight.withValues(alpha: 0.12),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.deepRose.withValues(alpha: 0.20),
                    blurRadius: 36,
                    spreadRadius: -6,
                  ),
                  BoxShadow(
                    color: AppColors.moonlight.withValues(alpha: 0.08),
                    blurRadius: 22,
                    spreadRadius: -10,
                  ),
                ],
              ),
              padding: const EdgeInsets.all(13),
              child: ClipOval(
                child: Image.asset('assets/images/logo.png', fit: BoxFit.cover),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'welcome home',
            style: AppTypography.handwrittenBody().copyWith(
              fontSize: 23,
              color: AppColors.blushGold.withValues(alpha: 0.92),
              height: 1.0,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 4),
          ShimmerTitle(
            child: Text(
              'Forever In Bloom',
              textAlign: TextAlign.center,
              style: AppTypography.cormorantBlack.copyWith(
                fontSize: titleSize,
                height: 1.0,
                letterSpacing: -0.6,
                shadows: [
                  BoxShadow(
                    color: AppColors.deepRose.withValues(alpha: 0.20),
                    blurRadius: 28,
                  ),
                  BoxShadow(
                    color: AppColors.moonlight.withValues(alpha: 0.10),
                    blurRadius: 14,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.blushGold.withValues(alpha: 0.7),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'since  February  14,  2026',
                style: AppTypography.outfitWhite.copyWith(
                  fontSize: 12.5,
                  color: AppColors.petalWhite.withValues(alpha: 0.68),
                  fontWeight: FontWeight.w500,
                  letterSpacing: 2.4,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.blushGold.withValues(alpha: 0.7),
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 42,
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      AppColors.blushGold.withValues(alpha: 0.65),
                    ],
                  ),
                ),
              ),
              Container(
                width: 3,
                height: 3,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: AppColors.blushGold.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
              ),
              const PulseHeart(
                child: Icon(
                  Icons.favorite_rounded,
                  color: AppColors.auroraRose,
                  size: 14,
                ),
              ),
              Container(
                width: 3,
                height: 3,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: AppColors.blushGold.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
              ),
              Container(
                width: 42,
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.blushGold.withValues(alpha: 0.65),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    // Distill: 6 editorial picks visible, 10 more behind a soft expand.
    // Keeps 60-second decision under 6 items (Miller), reduces wall tax.
    final primary = <QuickAction>[
      const QuickAction(
        label: 'Gallery',
        icon: Icons.photo_library_rounded,
        route: '/gallery',
        hue: AppColors.roseQuartz,
        caption: 'Memories',
      ),
      const QuickAction(
        label: 'Sanctuary',
        icon: Icons.chat_bubble_rounded,
        route: '/sanctuary',
        hue: AppColors.auroraRose,
        caption: 'Chat',
      ),
      const QuickAction(
        label: 'Canvas',
        icon: Icons.brush_rounded,
        route: '/canvas',
        hue: AppColors.softLavender,
        caption: 'Draw',
      ),
      const QuickAction(
        label: 'Mochi',
        icon: Icons.auto_awesome_rounded,
        route: '/mochi',
        hue: AppColors.auroraGold,
        caption: 'AI companion',
      ),
      const QuickAction(
        label: 'Calendar',
        icon: Icons.calendar_month_rounded,
        route: '/calendar',
        hue: AppColors.warmAmber,
        caption: 'Dates',
      ),
      const QuickAction(
        label: 'Starlight',
        icon: Icons.auto_awesome_mosaic_rounded,
        route: '/starlight',
        hue: AppColors.auroraLilac,
        caption: 'Gratitude',
      ),
    ];
    final more = <QuickAction>[
      const QuickAction(
        label: 'Journal',
        icon: Icons.menu_book_rounded,
        route: '/journal',
        hue: AppColors.softLavender,
        caption: 'Diary',
      ),
      const QuickAction(
        label: 'Cookbook',
        icon: Icons.restaurant_menu_rounded,
        route: '/cookbook',
        hue: AppColors.warmAmber,
        caption: 'Recipes',
      ),
      const QuickAction(
        label: 'Vault',
        icon: Icons.folder_special_rounded,
        route: '/vault',
        hue: AppColors.auroraTeal,
        caption: 'Drive',
      ),
      const QuickAction(
        label: 'Atlas',
        icon: Icons.map_rounded,
        route: '/travel',
        hue: AppColors.auroraTeal,
        caption: 'Trips',
      ),
      const QuickAction(
        label: 'Universe',
        icon: Icons.auto_stories_rounded,
        route: '/wiki',
        hue: AppColors.softLavender,
        caption: 'Lore',
      ),
      const QuickAction(
        label: 'Bucket List',
        icon: Icons.card_travel_rounded,
        route: '/bucket-list',
        hue: AppColors.auroraTeal,
        caption: 'Dreams',
      ),
      const QuickAction(
        label: 'Wellness',
        icon: Icons.favorite_rounded,
        route: '/wellness',
        hue: AppColors.auroraRose,
        caption: 'Habits',
      ),
      const QuickAction(
        label: 'Budget',
        icon: Icons.account_balance_wallet_rounded,
        route: '/budget',
        hue: AppColors.warmAmber,
        caption: 'Money',
      ),
      const QuickAction(
        label: 'Letterbox',
        icon: Icons.mail_outline_rounded,
        route: '/letterbox',
        hue: AppColors.blushGold,
        caption: 'Letters',
      ),
      const QuickAction(
        label: 'Ask',
        icon: Icons.search_rounded,
        route: '/rag',
        hue: AppColors.auroraLilac,
        caption: 'RAG',
      ),
    ];

    final visible = [...primary, ...more];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const EverglowSectionHeader(
          label: 'Quick Access',
          icon: Icons.grid_view_rounded,
          hue: AppColors.blushGold,
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth < 300 ? 3 : 4;
            final tileWidth = (constraints.maxWidth - ((columns - 1) * 12)) / columns;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final action in visible)
                  SizedBox(
                    width: tileWidth,
                    child: QuickActionTile(action: action),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
