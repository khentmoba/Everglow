part of 'episode_drawer.dart';

class _AiringCountdownChip extends StatefulWidget {
  final int nextAiringAt;
  final int? nextEpisode;
  const _AiringCountdownChip({required this.nextAiringAt, this.nextEpisode});

  @override
  State<_AiringCountdownChip> createState() => _AiringCountdownChipState();
}

class _AiringCountdownChipState extends State<_AiringCountdownChip> {
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String _formatCountdown() {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final diff = widget.nextAiringAt - now;
    if (diff <= 0) return 'Airing now';
    final d = diff ~/ 86400;
    final h = (diff % 86400) ~/ 3600;
    final m = (diff % 3600) ~/ 60;
    if (d > 0) return '${d}d ${h}h';
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.nextEpisode != null
        ? 'Ep ${widget.nextEpisode} in ${_formatCountdown()}'
        : 'Next in ${_formatCountdown()}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.deepRose.withValues(alpha: 0.25),
            AppColors.deepRose.withValues(alpha: 0.12),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.deepRose.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.timer_outlined, color: AppColors.deepRose, size: 11),
          const SizedBox(width: 5),
          Text(
            label,
            style: AppTypography.outfitHeading.copyWith(
              color: AppColors.deepRose,
              fontSize: 10,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}


  Widget _buildGenreChip(String name) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.shimmerBase,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.moonlight.withValues(alpha: 0.14),
          width: 1,
        ),
      ),
      child: Text(
        name,
        style: AppTypography.outfitBold.copyWith(
          color: AppColors.textMedium,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _buildEnhancedGenreChip(String name) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.surfaceGlass,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.roseQuartz.withValues(alpha: 0.25)),
      ),
      child: Text(
        name,
        style: AppTypography.outfitBold.copyWith(
          color: AppColors.roseQuartz.withValues(alpha: 0.95),
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildEnhancedAnimeFactChip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.blushGold.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.blushGold.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.blushGold, size: 12),
          const SizedBox(width: 5),
          Text(
            label,
            style: AppTypography.outfitHeading.copyWith(
              color: AppColors.blushGold,
              fontSize: 10.5,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimeFactChip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.shimmerBase,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.blushGold.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.blushGold, size: 11),
          const SizedBox(width: 5),
          Text(
            label,
            style: AppTypography.outfitHeading.copyWith(
              color: AppColors.blushGold,
              fontSize: 10,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiringCountdownChip(int nextAiringAtSeconds, int? nextEpisode) {
    return _AiringCountdownChip(
      nextAiringAt: nextAiringAtSeconds,
      nextEpisode: nextEpisode,
    );
  }
