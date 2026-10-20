part of 'books_screen.dart';

/// Tune button next to the search box. Glows amber while advanced
/// filters are active so Clair can see at a glance that the list
/// is narrowed.
class _AdvancedButton extends StatelessWidget {
  final bool active;
  final VoidCallback onTap;
  const _AdvancedButton({required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Tooltip(
        message: 'Advanced search',
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: active
                ? _cAmber.withValues(alpha: 0.18)
                : _cCard,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: active
                  ? _cAmber.withValues(alpha: 0.5)
                  : _cRose.withValues(alpha: 0.15),
            ),
          ),
          child: Icon(
            Icons.tune_rounded,
            color: active ? _cAmber : _cDeepRose,
            size: 22,
          ),
        ),
      ),
    );
  }
}

/// Z-Lib style "Load more" footer for the paged result list.
class _LoadMoreRow extends StatelessWidget {
  final bool loading;
  final VoidCallback onTap;
  const _LoadMoreRow({required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: loading ? null : onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: _cDeepRose.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _cDeepRose.withValues(alpha: 0.3)),
          ),
          alignment: Alignment.center,
          child: loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: _cDeepRose,
                    strokeWidth: 2.5,
                  ),
                )
              : Text(
                  'Load more results',
                  style: AppTypography.outfitBold.copyWith(
                    color: _cDeepRose,
                    fontSize: 13,
                  ),
                ),
        ),
      ),
    );
  }
}
