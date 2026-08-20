import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_radius.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/theme/app_typography.dart';
import '../../providers/music_insights_provider.dart';

class DiscoveryRaceCard extends StatelessWidget {
  const DiscoveryRaceCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<MusicInsightsProvider>(
      builder: (context, p, _) {
        if (p.isLoading && p.discovery.isEmpty) {
          return Container(height: 180, decoration: BoxDecoration(color: AppColors.shimmerBase, borderRadius: AppRadius.radiusX2));
        }
        final entries = p.discovery;
        if (entries.isEmpty) {
          return Container(
            decoration: BoxDecoration(borderRadius: AppRadius.radiusX2, gradient: LinearGradient(colors: [AppColors.velvet.withValues(alpha: 0.86), AppColors.inkDeep.withValues(alpha: 0.90)], begin: Alignment.topLeft, end: Alignment.bottomRight), border: Border.all(color: AppColors.moonlight.withValues(alpha: 0.14))),
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(children: [
              const Icon(Icons.emoji_events_outlined, size: 24, color: AppColors.blushGold),
              const SizedBox(height: 8),
              Text('DISCOVERY RACE', style: AppTypography.outfitBold.copyWith(fontSize: 10, letterSpacing: 1.6, color: AppColors.blushGold)),
              const SizedBox(height: 6),
              Text('No shared artists with history just yet — listen together and see who discovered whom first.', textAlign: TextAlign.center, style: AppTypography.outfitMedium.copyWith(fontSize: 12, color: AppColors.textMedium)),
            ]),
          );
        }

        final khentWins = entries.where((e) => e.winner == 'khent').length;
        final clairWins = entries.where((e) => e.winner == 'clair').length;
        final ties = entries.where((e) => e.winner == 'tie').length;

        return Container(
          decoration: BoxDecoration(
            borderRadius: AppRadius.radiusX2,
            gradient: LinearGradient(colors: [AppColors.velvet.withValues(alpha: 0.90), AppColors.inkDeep.withValues(alpha: 0.96)], begin: Alignment.topLeft, end: Alignment.bottomRight),
            border: Border.all(color: AppColors.auroraGold.withValues(alpha: 0.16)),
            boxShadow: [BoxShadow(color: AppColors.inkDeep.withValues(alpha: 0.45), blurRadius: 22, offset: const Offset(0, 8))],
          ),
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(width: 36, height: 36, decoration: BoxDecoration(shape: BoxShape.circle, gradient: const LinearGradient(colors: [Color(0xFFF5C97B), Color(0xFFFF7AA2)], begin: Alignment.topLeft, end: Alignment.bottomRight)), child: const Icon(Icons.flag_rounded, size: 18, color: Colors.white)),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('DISCOVERY RACE', style: AppTypography.outfitBold.copyWith(fontSize: 10, letterSpacing: 1.8, color: AppColors.blushGold)),
                  Text('Who heard it first?', style: AppTypography.outfitMedium.copyWith(fontSize: 11, color: AppColors.textMuted)),
                ])),
                _ScoreChip(khent: khentWins, clair: clairWins, ties: ties),
              ]),
              const SizedBox(height: AppSpacing.lg),
              // podium for top 3
              if (entries.length >= 3)
                Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Expanded(child: _Podium(entry: entries[1], height: 72, color: const Color(0xFFB9BBFF))),
                  const SizedBox(width: 8),
                  Expanded(child: _Podium(entry: entries[0], height: 96, color: AppColors.auroraGold, isFirst: true)),
                  const SizedBox(width: 8),
                  Expanded(child: _Podium(entry: entries.length > 2 ? entries[2] : entries[1], height: 64, color: const Color(0xFFE8A87C))),
                ]),
              if (entries.length >= 3) const SizedBox(height: AppSpacing.lg),
              Column(children: entries.map((e) => _RaceRow(entry: e)).toList()),
            ],
          ),
        );
      },
    );
  }
}

class _ScoreChip extends StatelessWidget {
  final int khent;
  final int clair;
  final int ties;
  const _ScoreChip({required this.khent, required this.clair, required this.ties});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(99), border: Border.all(color: Colors.white.withValues(alpha: 0.08))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text('K $khent', style: AppTypography.outfitBold.copyWith(fontSize: 10, color: AppColors.auroraTeal)),
          Text(' · ', style: AppTypography.outfitMedium.copyWith(color: AppColors.textMuted, fontSize: 10)),
          Text('C $clair', style: AppTypography.outfitBold.copyWith(fontSize: 10, color: AppColors.cinemaPink)),
          if (ties > 0) ...[Text(' · ', style: AppTypography.outfitMedium.copyWith(color: AppColors.textMuted, fontSize: 10)), Text('T $ties', style: AppTypography.outfitBold.copyWith(fontSize: 10, color: AppColors.auroraGold))],
        ]),
      );
}

class _Podium extends StatelessWidget {
  final DiscoveryEntry entry;
  final double height;
  final Color color;
  final bool isFirst;
  const _Podium({required this.entry, required this.height, required this.color, this.isFirst = false});
  @override
  Widget build(BuildContext context) {
    final winnerLabel = entry.winner == 'khent' ? 'Khent' : entry.winner == 'clair' ? 'Clair' : entry.winner == 'tie' ? 'Tie' : '—';
    final winnerColor = entry.winner == 'khent' ? AppColors.auroraTeal : entry.winner == 'clair' ? AppColors.cinemaPink : AppColors.auroraGold;
    return Column(children: [
      Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [color.withValues(alpha: 0.9), color], begin: Alignment.topLeft, end: Alignment.bottomRight), border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 1.2), boxShadow: [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 14)]),
        child: Icon(isFirst ? Icons.emoji_events_rounded : Icons.workspace_premium_rounded, size: 22, color: isFirst ? const Color(0xFF6B4E00) : Colors.white),
      ),
      const SizedBox(height: 6),
      Text(entry.artistName, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: AppTypography.outfitHeading.copyWith(fontSize: 11, color: AppColors.petalWhite)),
      Text(winnerLabel, style: AppTypography.outfitBold.copyWith(fontSize: 9, letterSpacing: 0.8, color: winnerColor)),
      const SizedBox(height: 6),
      Container(
        height: height,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [color.withValues(alpha: 0.28), color.withValues(alpha: 0.12)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        alignment: Alignment.center,
        child: Text(isFirst ? '1' : entry == entry ? '2' : '3', style: AppTypography.cormorantBoldWhite.copyWith(fontSize: 18, color: color)),
      ),
    ]);
  }
}

class _RaceRow extends StatelessWidget {
  final DiscoveryEntry entry;
  const _RaceRow({required this.entry});
  @override
  Widget build(BuildContext context) {
    final winner = entry.winner;
    final winnerColor = winner == 'khent' ? AppColors.auroraTeal : winner == 'clair' ? AppColors.cinemaPink : winner == 'tie' ? AppColors.auroraGold : AppColors.textMuted;
    final winnerText = winner == 'khent' ? 'Khent first' : winner == 'clair' ? 'Clair first' : winner == 'tie' ? 'Same moment ♡' : 'Unknown';
    final khentDate = entry.khentFirst != null ? DateFormat('MMM d, y').format(entry.khentFirst!) : '—';
    final clairDate = entry.clairFirst != null ? DateFormat('MMM d, y').format(entry.clairFirst!) : '—';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.04), borderRadius: AppRadius.radiusLg, border: Border.all(color: Colors.white.withValues(alpha: 0.07))),
      child: Row(
        children: [
          Container(width: 40, height: 40, decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: winnerColor.withValues(alpha: 0.18), border: Border.all(color: winnerColor.withValues(alpha: 0.32))), child: Icon(winner == 'khent' ? Icons.person_rounded : winner == 'clair' ? Icons.person_rounded : Icons.favorite_rounded, size: 18, color: winnerColor)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(entry.artistName, style: AppTypography.outfitHeading.copyWith(fontSize: 13, color: AppColors.petalWhite)),
            const SizedBox(height: 2),
            Row(children: [
              Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: winnerColor.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(99), border: Border.all(color: winnerColor.withValues(alpha: 0.28))), child: Text(winnerText.toUpperCase(), style: AppTypography.outfitBold.copyWith(fontSize: 8, letterSpacing: 0.8, color: winnerColor))),
              const SizedBox(width: 6),
              Expanded(child: Text('$khentDate • $clairDate', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.outfitMedium.copyWith(fontSize: 10, color: AppColors.textMuted))),
            ]),
          ])),
          const SizedBox(width: 8),
          if (winner == 'khent' || winner == 'clair')
            Container(width: 28, height: 28, decoration: BoxDecoration(shape: BoxShape.circle, color: winnerColor, border: Border.all(color: Colors.white.withValues(alpha: 0.8))), child: Icon(Icons.emoji_events_rounded, size: 14, color: winner == 'khent' ? Colors.white : Colors.white)),
        ],
      ),
    );
  }
}
