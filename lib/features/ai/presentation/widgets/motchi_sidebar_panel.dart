part of 'motchi_sidebar.dart';

class _SidebarPanel extends StatelessWidget {
  final TextEditingController searchCtl;
  final String query;
  final ValueChanged<String> onQueryChanged;
  final List<AISession> sessions;
  final bool isLoading;
  final Map<String, List<AISession>> grouped;
  final String? activeId;
  final VoidCallback onNewChat;
  final VoidCallback onClose;
  final ValueChanged<AISession> onSwitch;
  final ValueChanged<AISession> onDelete;
  final VoidCallback onRefresh;
  final bool desktop;

  const _SidebarPanel({
    required this.searchCtl,
    required this.query,
    required this.onQueryChanged,
    required this.sessions,
    required this.isLoading,
    required this.grouped,
    required this.activeId,
    required this.onNewChat,
    required this.onClose,
    required this.onSwitch,
    required this.onDelete,
    required this.onRefresh,
    required this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    final topPad = desktop ? 0.0 : MediaQuery.paddingOf(context).top;
    final bottomPad = desktop ? 0.0 : MediaQuery.paddingOf(context).bottom;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.twilight,
        border: Border(
          right: BorderSide(
            color: AppColors.blushGold.withValues(alpha: 0.12),
            width: 1,
          ),
          left: desktop
              ? BorderSide(
                  color: AppColors.blushGold.withValues(alpha: 0.06),
                  width: 1,
                )
              : BorderSide.none,
        ),
        boxShadow: desktop
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.45),
                  blurRadius: 24,
                  offset: const Offset(4, 0),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(context, topPad),
          Divider(
            height: 1,
            thickness: 1,
            color: AppColors.blushGold.withValues(alpha: 0.07),
          ),
          _buildNewChatButton(),
          _buildMotchiHub(context),
          _buildSearch(context),
          _buildHistoryHeader(),
          Expanded(
            child: isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.blushGold.withValues(alpha: 0.75),
                    ),
                  )
                : sessions.isEmpty
                ? _buildEmpty(query.isNotEmpty)
                : _buildSessionList(),
          ),
          _buildFooter(bottomPad),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, double topPad) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 12 + topPad, 12, 12),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  borderRadius: AppRadius.radiusMd,
                  border: Border.all(
                    color: AppColors.blushGold.withValues(alpha: 0.4),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.blushGold.withValues(alpha: 0.18),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(13),
                  child: Image.asset(
                    'assets/images/motchi_avatar.webp',
                    width: 36,
                    height: 36,
                    cacheWidth: kIsWeb ? null : 108,
                    cacheHeight: kIsWeb ? null : 108,
                    filterQuality: FilterQuality.high,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Positioned(
                right: -1,
                bottom: -1,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.twilight, width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Motchi',
                      style: AppTypography.titleMedium().copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textHigh,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1.5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.blushGold.withValues(alpha: 0.14),
                        borderRadius: AppRadius.radiusFull,
                      ),
                      child: Text(
                        '🐾 CAT',
                        style: AppTypography.labelSmall().copyWith(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                          color: AppColors.blushGold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Chat & Memories',
                  style: AppTypography.bodySmall().copyWith(
                    color: AppColors.textMuted,
                    fontSize: 11,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
          Tooltip(
            message: 'Close sidebar',
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onClose,
                borderRadius: AppRadius.radiusSm,
                child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceGlass,
                    borderRadius: AppRadius.radiusSm,
                    border: Border.all(
                      color: AppColors.blushGold.withValues(alpha: 0.12),
                    ),
                  ),
                  child: Icon(
                    Icons.close_rounded,
                    color: AppColors.textMedium,
                    size: 17,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNewChatButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onNewChat,
          borderRadius: AppRadius.radiusLg,
          child: Ink(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.blushGold, AppColors.deepRose],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: AppRadius.radiusLg,
              boxShadow: [
                BoxShadow(
                  color: AppColors.deepRose.withValues(alpha: 0.28),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                const Icon(
                  Icons.add_rounded,
                  color: AppColors.petalWhite,
                  size: 19,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'New conversation',
                    style: AppTypography.bodySmall().copyWith(
                      color: AppColors.petalWhite,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  Icons.auto_awesome_rounded,
                  color: AppColors.petalWhite.withValues(alpha: 0.85),
                  size: 15,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMotchiHub(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 2, 12, 6),
      child: Row(
        children: [
          Expanded(
            child: _HubTile(
              icon: Icons.wb_twilight_rounded,
              label: 'Today',
              accent: AppColors.auroraGold,
              onTap: () {
                if (!desktop) onClose();
                context.push('/motchi-today');
              },
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _HubTile(
              icon: Icons.menu_book_rounded,
              label: 'Memories',
              accent: AppColors.roseQuartz,
              onTap: () {
                if (!desktop) onClose();
                context.push('/motchi-memory');
              },
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _HubTile(
              icon: Icons.psychology_rounded,
              label: 'Trivia',
              accent: AppColors.auroraLilac,
              onTap: () {
                if (!desktop) onClose();
                context.push('/motchi-trivia');
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearch(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 2, 12, 6),
      child: TextField(
        controller: searchCtl,
        onChanged: onQueryChanged,
        style: AppTypography.bodySmall().copyWith(color: AppColors.textHigh),
        decoration: InputDecoration(
          hintText: 'Search conversations...',
          hintStyle: AppTypography.bodySmall().copyWith(
            color: AppColors.textDisabled,
            fontSize: 12.5,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            size: 17,
            color: query.isNotEmpty ? AppColors.blushGold : AppColors.textMuted,
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 34,
            minHeight: 34,
          ),
          suffixIcon: query.isNotEmpty
              ? IconButton(
                  onPressed: () {
                    searchCtl.clear();
                    onQueryChanged('');
                  },
                  icon: Icon(
                    Icons.close_rounded,
                    size: 15,
                    color: AppColors.textMuted,
                  ),
                  splashRadius: 14,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                )
              : null,
          isDense: true,
          filled: true,
          fillColor: AppColors.surfaceGlass,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8.5,
          ),
          border: OutlineInputBorder(
            borderRadius: AppRadius.radiusLg,
            borderSide: BorderSide(
              color: AppColors.blushGold.withValues(alpha: 0.12),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: AppRadius.radiusLg,
            borderSide: BorderSide(
              color: AppColors.blushGold.withValues(alpha: 0.12),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: AppRadius.radiusLg,
            borderSide: BorderSide(
              color: AppColors.blushGold.withValues(alpha: 0.45),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 12, 4),
      child: Row(
        children: [
          Text(
            'History',
            style: AppTypography.bodySmall().copyWith(
              color: AppColors.textMuted.withValues(alpha: 0.8),
              fontWeight: FontWeight.w700,
              fontSize: 11.5,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: AppColors.surfaceGlass,
              borderRadius: AppRadius.radiusFull,
              border: Border.all(
                color: AppColors.blushGold.withValues(alpha: 0.15),
              ),
            ),
            child: Text(
              '${sessions.length}',
              style: AppTypography.labelSmall().copyWith(
                color: AppColors.blushGold,
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (query.isNotEmpty) ...[
            const SizedBox(width: 6),
            Text(
              'filtered',
              style: AppTypography.bodySmall().copyWith(
                color: AppColors.textDisabled,
                fontSize: 10,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          const Spacer(),
          IconButton(
            onPressed: onRefresh,
            icon: Icon(
              Icons.refresh_rounded,
              color: AppColors.textMuted,
              size: 17,
            ),
            tooltip: 'Refresh conversations',
            splashRadius: 18,
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints.tightFor(width: 36, height: 36),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionList() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      children: grouped.entries.map((entry) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
              child: Row(
                children: [
                  Text(
                    entry.key,
                    style: AppTypography.bodySmall().copyWith(
                      color: AppColors.textMuted.withValues(alpha: 0.65),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '· ${entry.value.length}',
                    style: AppTypography.bodySmall().copyWith(
                      color: AppColors.textDisabled,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            ...entry.value.map(
              (session) => _SessionItem(
                session: session,
                isActive: session.id == activeId,
                onTap: () => onSwitch(session),
                onDelete: () => onDelete(session),
              ),
            ),
            const SizedBox(height: 4),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildEmpty(bool searching) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              searching ? Icons.search_off_rounded : Icons.pets_rounded,
              color: AppColors.blushGold.withValues(alpha: 0.45),
              size: 30,
            ),
            const SizedBox(height: 10),
            Text(
              searching
                  ? 'No matches for “$query”.'
                  : 'No conversations yet.\nStart chatting to see history here.',
              textAlign: TextAlign.center,
              style: AppTypography.bodySmall().copyWith(
                color: AppColors.textMuted,
                height: 1.4,
                fontSize: 12,
              ),
            ),
            if (searching) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () {
                  searchCtl.clear();
                  onQueryChanged('');
                },
                icon: const Icon(Icons.clear_rounded, size: 14),
                label: const Text('Clear search'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.blushGold,
                  textStyle: AppTypography.labelSmall(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFooter(double bottomPad) {
    return Container(
      padding: EdgeInsets.fromLTRB(14, 8, 14, 8 + bottomPad),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: AppColors.blushGold.withValues(alpha: 0.07),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.lock_outline_rounded,
            size: 12,
            color: AppColors.textDisabled,
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              'Private to Khent & Clair',
              style: AppTypography.bodySmall().copyWith(
                color: AppColors.textDisabled,
                fontSize: 10,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Icon(
            Icons.cloud_done_rounded,
            size: 12,
            color: AppColors.success.withValues(alpha: 0.75),
          ),
          const SizedBox(width: 4),
          Text(
            'Synced',
            style: AppTypography.bodySmall().copyWith(
              color: AppColors.textDisabled,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}
