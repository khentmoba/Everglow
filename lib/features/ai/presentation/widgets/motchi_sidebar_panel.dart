part of 'motchi_sidebar.dart';

class _SidebarPanel extends StatelessWidget {
  final TextEditingController searchCtl;
  final String query;
  final ValueChanged<String> onQueryChanged;
  final List<AISession> sessions;
  final bool isLoading;
  final bool historyFailed;
  final String? switchingId;
  final bool busy;
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
    required this.historyFailed,
    required this.switchingId,
    required this.busy,
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
        color: AppColors.inkDeep,
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
          if (historyFailed)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'History couldn’t load. Your current chat is still here.',
                    style: AppTypography.bodySmall().copyWith(
                      color: AppColors.textMedium,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: isLoading ? null : onRefresh,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Try again'),
                  ),
                ],
              ),
            ),
          Expanded(
            child: isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.blushGold.withValues(alpha: 0.75),
                    ),
                  )
                : sessions.isEmpty
                ? historyFailed
                      ? const SizedBox.shrink()
                      : _buildEmpty(query.isNotEmpty)
                : _buildSessionList(),
          ),
          _buildFooter(bottomPad),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, double topPad) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 8 + topPad, 8, 8),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: AppRadius.radiusXs,
            child: Image.asset(
              'assets/images/motchi_avatar.webp',
              width: 24,
              height: 24,
              cacheWidth: PerfSettings.sizedDecodeWidth(72),
              cacheHeight: PerfSettings.sizedDecodeWidth(72),
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Motchi',
              style: AppTypography.titleMedium().copyWith(
                fontFamily: AppTypography.reading,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Close sidebar',
            visualDensity: VisualDensity.standard,
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded, size: 20),
            color: AppColors.textMuted,
          ),
        ],
      ),
    );
  }

  Widget _buildNewChatButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: FilledButton.icon(
        onPressed: busy ? null : onNewChat,
        icon: const Icon(Icons.add_rounded, size: 19),
        label: const Text('New conversation'),
        style: FilledButton.styleFrom(
          alignment: Alignment.centerLeft,
          minimumSize: const Size.fromHeight(48),
          visualDensity: VisualDensity.standard,
          backgroundColor: AppColors.glassSoft,
          foregroundColor: AppColors.petalWhite,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusSm),
          textStyle: AppTypography.bodyMedium().copyWith(
            fontFamily: AppTypography.reading,
            fontWeight: FontWeight.w400,
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
                  tooltip: 'Clear search',
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
                    minWidth: 44,
                    minHeight: 44,
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
            onPressed: isLoading ? null : onRefresh,
            icon: Icon(
              Icons.refresh_rounded,
              color: AppColors.textMuted,
              size: 17,
            ),
            tooltip: 'Refresh conversations',
            splashRadius: 16,
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.standard,
            constraints: const BoxConstraints.tightFor(width: 44, height: 44),
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
                onTap: busy ? null : () => onSwitch(session),
                onDelete: busy ? null : () => onDelete(session),
                isLoading: switchingId == session.id,
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
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottomPad),
      child: Row(
        children: [
          Icon(
            Icons.lock_outline_rounded,
            size: 12,
            color: AppColors.textDisabled,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Private to Khent & Clair',
              style: AppTypography.bodySmall().copyWith(
                fontFamily: AppTypography.reading,
                fontWeight: FontWeight.w400,
                color: AppColors.textDisabled,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
