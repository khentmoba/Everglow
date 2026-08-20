import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_radius.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/theme/app_typography.dart';
import '../../providers/music_insights_provider.dart';
import '../../../data/models/loved_track.dart';
import '../../../data/services/jukebox_dedication_service.dart';
import '../../../data/models/lastfm_image_utils.dart';
import '../../../../../core/services/auth_service.dart';

class LovedTracksSection extends StatefulWidget {
  const LovedTracksSection({super.key});
  @override
  State<LovedTracksSection> createState() => _LovedTracksSectionState();
}

class _LovedTracksSectionState extends State<LovedTracksSection> {
  final _dedicationService = JukeboxDedicationService();
  String _filter = 'both'; // both | khent | clair

  @override
  Widget build(BuildContext context) {
    return Consumer<MusicInsightsProvider>(
      builder: (context, p, _) {
        if (p.isLoading && p.khentLoved.isEmpty && p.clairLoved.isEmpty) {
          return Container(height: 200, decoration: BoxDecoration(color: AppColors.shimmerBase, borderRadius: AppRadius.radiusX2));
        }
        final khent = p.khentLoved;
        final clair = p.clairLoved;
        final isEmpty = khent.isEmpty && clair.isEmpty;

        List<LovedTrack> filtered;
        String ownerLabel;
        if (_filter == 'khent') {
          filtered = khent;
          ownerLabel = 'Khent';
        } else if (_filter == 'clair') {
          filtered = clair;
          ownerLabel = 'Clair';
        } else {
          filtered = [...khent.take(6), ...clair.take(6)];
          filtered.shuffle();
          filtered = filtered.take(12).toList();
          ownerLabel = 'Both';
        }

        return Container(
          decoration: BoxDecoration(
            borderRadius: AppRadius.radiusX2,
            gradient: LinearGradient(colors: [AppColors.velvet.withValues(alpha: 0.88), AppColors.inkDeep.withValues(alpha: 0.92)], begin: Alignment.topLeft, end: Alignment.bottomRight),
            border: Border.all(color: AppColors.moonlight.withValues(alpha: 0.14)),
            boxShadow: [BoxShadow(color: AppColors.inkDeep.withValues(alpha: 0.45), blurRadius: 22, offset: const Offset(0, 8))],
          ),
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(shape: BoxShape.circle, gradient: const LinearGradient(colors: [Color(0xFFFF6F91), Color(0xFFE91E8C)], begin: Alignment.topLeft, end: Alignment.bottomRight), border: Border.all(color: Colors.white.withValues(alpha: 0.7))),
                    child: const Icon(Icons.favorite_rounded, size: 18, color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('LOVED TRACKS', style: AppTypography.outfitBold.copyWith(fontSize: 10, letterSpacing: 1.8, color: AppColors.blushGold)),
                    Text(isEmpty ? 'No loved tracks yet' : '${khent.length + clair.length} hearts collected', style: AppTypography.outfitMedium.copyWith(fontSize: 11, color: AppColors.textMuted)),
                  ])),
                  _FilterChip(label: 'Both', selected: _filter == 'both', onTap: () => setState(() => _filter = 'both')),
                  const SizedBox(width: 6),
                  _FilterChip(label: 'Khent', selected: _filter == 'khent', onTap: () => setState(() => _filter = 'khent')),
                  const SizedBox(width: 6),
                  _FilterChip(label: 'Clair', selected: _filter == 'clair', onTap: () => setState(() => _filter = 'clair')),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              if (isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: AppRadius.radiusMd, border: Border.all(color: Colors.white.withValues(alpha: 0.07))),
                  child: Column(children: [
                    const Icon(Icons.favorite_border_rounded, size: 22, color: AppColors.roseQuartz),
                    const SizedBox(height: 8),
                    Text('Love a track on Last.fm and it will bloom here as a dedication.', textAlign: TextAlign.center, style: AppTypography.outfitMedium.copyWith(fontSize: 12, color: AppColors.textMedium)),
                  ]),
                )
              else if (filtered.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.04), borderRadius: AppRadius.radiusMd),
                  child: Text('$ownerLabel hasn\'t loved anything yet — tap ♥ on Last.fm to start.', style: AppTypography.outfitMedium.copyWith(fontSize: 12, color: AppColors.textMedium)),
                )
              else
                Column(
                  children: [
                    // Horizontal scroll of loved cards
                    SizedBox(
                      height: 148,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (context, i) {
                          final t = filtered[i];
                          final owner = khent.contains(t) ? 'Khent' : clair.contains(t) ? 'Clair' : (i % 2 == 0 ? 'Khent' : 'Clair');
                          return _LovedCard(track: t, owner: owner, onDedicate: () => _openDedicate(context, t, owner));
                        },
                      ),
                    ),
                    const SizedBox(height: 14),
                    // dedications stream
                    StreamBuilder(
                      stream: _dedicationService.dedicationsStream(),
                      builder: (context, snap) {
                        final dedications = snap.data ?? [];
                        if (dedications.isEmpty) return const SizedBox.shrink();
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              const Icon(Icons.card_giftcard_rounded, size: 14, color: AppColors.auroraGold),
                              const SizedBox(width: 6),
                              Text('RECENT DEDICATIONS', style: AppTypography.outfitBold.copyWith(fontSize: 10, letterSpacing: 1.2, color: AppColors.auroraGold)),
                            ]),
                            const SizedBox(height: 8),
                            Column(children: dedications.take(3).map((d) => Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(color: AppColors.auroraGold.withValues(alpha: 0.06), borderRadius: AppRadius.radiusMd, border: Border.all(color: AppColors.auroraGold.withValues(alpha: 0.18))),
                                  child: Row(children: [
                                    Container(width: 36, height: 36, decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: AppColors.velvet), child: d.imageUrl == null ? const Icon(Icons.music_note_rounded, size: 16, color: AppColors.roseQuartz) : ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(cleanLastfmImageUrl(d.imageUrl) ?? d.imageUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.music_note_rounded, size: 16, color: AppColors.roseQuartz)))),
                                    const SizedBox(width: 10),
                                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Text('${d.fromUsername} → ${d.toUsername}', style: AppTypography.outfitBold.copyWith(fontSize: 10, letterSpacing: 0.8, color: AppColors.blushGold)),
                                      Text('${d.trackName} • ${d.artistName}', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.outfitHeading.copyWith(fontSize: 12, color: AppColors.petalWhite)),
                                      if (d.message != null && d.message!.isNotEmpty) Text('"${d.message}"', style: AppTypography.outfitMedium.copyWith(fontSize: 11, color: AppColors.textMedium, fontStyle: FontStyle.italic)),
                                    ])),
                                  ]),
                                )).toList()),
                          ],
                        );
                      },
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }

  void _openDedicate(BuildContext context, LovedTrack track, String owner) {
    final auth = context.read<AuthService>();
    final current = auth.currentUser ?? 'khentsgdz';
    final target = owner.toLowerCase() == 'khent' ? 'clairjassen' : 'khentsgdz';
    final from = current == 'clairjassen' ? 'clairjassen' : 'khentsgdz';
    final to = from == 'khentsgdz' ? 'clairjassen' : 'khentsgdz';
    final msgCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.inkDeep,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusX2, side: BorderSide(color: AppColors.moonlight.withValues(alpha: 0.14))),
        title: Text('Dedicate this track?', style: AppTypography.cormorantBoldWhite.copyWith(fontSize: 20)),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                Container(width: 48, height: 48, decoration: BoxDecoration(borderRadius: AppRadius.radiusMd, color: AppColors.velvet), child: ClipRRect(borderRadius: AppRadius.radiusMd, child: () {
                  final u = cleanLastfmImageUrl(track.imageUrl);
                  if (u == null) return const Icon(Icons.music_note_rounded, color: AppColors.roseQuartz);
                  return Image.network(u, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.music_note_rounded, color: AppColors.roseQuartz));
                }())),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(track.trackName, style: AppTypography.outfitHeading.copyWith(fontSize: 14, color: AppColors.petalWhite)),
                  Text(track.artistName, style: AppTypography.outfitMedium.copyWith(fontSize: 12, color: AppColors.textMedium)),
                  Text('from $owner • to ${to == 'khentsgdz' ? 'Khent' : 'Clair'}', style: AppTypography.outfitBold.copyWith(fontSize: 10, letterSpacing: 0.8, color: AppColors.blushGold)),
                ])),
              ]),
              const SizedBox(height: 14),
              TextField(
                controller: msgCtrl,
                maxLength: 140,
                maxLines: 2,
                style: AppTypography.outfitMedium.copyWith(color: AppColors.petalWhite, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Add a note (optional) — e.g. "this reminded me of you"',
                  hintStyle: AppTypography.outfitMedium.copyWith(color: AppColors.textMuted, fontSize: 12),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.06),
                  border: OutlineInputBorder(borderRadius: AppRadius.radiusMd, borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
                  enabledBorder: OutlineInputBorder(borderRadius: AppRadius.radiusMd, borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
                  focusedBorder: OutlineInputBorder(borderRadius: AppRadius.radiusMd, borderSide: BorderSide(color: AppColors.auroraRose.withValues(alpha: 0.4))),
                  counterStyle: AppTypography.outfitMedium.copyWith(fontSize: 10, color: AppColors.textMuted),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: AppTypography.outfitBold.copyWith(color: AppColors.textMuted))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.auroraRose, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99))),
            onPressed: () async {
              try {
                await _dedicationService.dedicate(fromUsername: from, toUsername: target, trackName: track.trackName, artistName: track.artistName, imageUrl: track.imageUrl, message: msgCtrl.text.trim().isEmpty ? null : msgCtrl.text.trim());
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Dedicated “${track.trackName}” to ${target == 'khentsgdz' ? 'Khent' : 'Clair'} ♡', style: AppTypography.outfitMedium.copyWith(color: AppColors.petalWhite)), backgroundColor: AppColors.velvet, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusLg)));
              } catch (e) {
                if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Could not dedicate: $e')));
              }
            },
            child: Text('Dedicate ♡', style: AppTypography.outfitBold.copyWith(color: Colors.white, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? AppColors.auroraRose.withValues(alpha: 0.16) : Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: selected ? AppColors.auroraRose.withValues(alpha: 0.35) : Colors.white.withValues(alpha: 0.08)),
          ),
          child: Text(label.toUpperCase(), style: AppTypography.outfitBold.copyWith(fontSize: 9, letterSpacing: 0.9, color: selected ? AppColors.auroraRose : AppColors.textMedium)),
        ),
      );
}

class _LovedCard extends StatelessWidget {
  final LovedTrack track;
  final String owner;
  final VoidCallback onDedicate;
  const _LovedCard({required this.track, required this.owner, required this.onDedicate});
  @override
  Widget build(BuildContext context) {
    final isKhent = owner.toLowerCase() == 'khent';
    final color = isKhent ? AppColors.auroraTeal : AppColors.cinemaPink;
    return Container(
      width: 160,
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.04), borderRadius: AppRadius.radiusLg, border: Border.all(color: Colors.white.withValues(alpha: 0.08))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: Container(
                height: 84,
                width: double.infinity,
                color: AppColors.velvet,
                child: () {
                  final u = cleanLastfmImageUrl(track.imageUrl);
                  if (u == null) return const Icon(Icons.music_note_rounded, size: 24, color: AppColors.roseQuartz);
                  return Image.network(u, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.music_note_rounded, size: 24, color: AppColors.roseQuartz));
                }(),
              ),
            ),
            Positioned(top: 8, left: 8, child: Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3), decoration: BoxDecoration(color: color.withValues(alpha: 0.92), borderRadius: BorderRadius.circular(99)), child: Text(owner.toUpperCase(), style: AppTypography.outfitBold.copyWith(fontSize: 8, letterSpacing: 0.8, color: Colors.white)))),
            Positioned(top: 8, right: 8, child: Container(width: 26, height: 26, decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.auroraRose, border: Border.all(color: Colors.white.withValues(alpha: 0.85)), boxShadow: [BoxShadow(color: AppColors.auroraRose.withValues(alpha: 0.35), blurRadius: 10)]), child: const Icon(Icons.favorite_rounded, size: 14, color: Colors.white))),
          ]),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(track.trackName, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.outfitHeading.copyWith(fontSize: 12, color: AppColors.petalWhite)),
              Text(track.artistName, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.outfitMedium.copyWith(fontSize: 10, color: AppColors.textMedium)),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                height: 26,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(padding: EdgeInsets.zero, side: BorderSide(color: AppColors.auroraRose.withValues(alpha: 0.35)), backgroundColor: AppColors.auroraRose.withValues(alpha: 0.08), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99))),
                  onPressed: onDedicate,
                  child: Text('Dedicate ♡', style: AppTypography.outfitBold.copyWith(fontSize: 10, color: AppColors.auroraRose)),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}
