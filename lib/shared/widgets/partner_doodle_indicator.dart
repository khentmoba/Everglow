import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models/presence_status.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/presence_service.dart';
import 'everglow/everglow_presence_dot.dart';

class PartnerDoodleIndicator extends StatefulWidget {
  const PartnerDoodleIndicator({super.key});

  @override
  State<PartnerDoodleIndicator> createState() => _PartnerDoodleIndicatorState();
}

class _PartnerDoodleIndicatorState extends State<PartnerDoodleIndicator> {
  Timer? _ticker;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final presence = context.read<PresenceService>();
    final partnerUid = authService.partnerUid;
    final partnerName = authService.partnerName;

    if (partnerUid == null) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<PresenceStatus>(
      stream: presence.watchPresence(partnerUid),
      builder: (context, snapshot) {
        final status = snapshot.data ?? PresenceStatus.empty(partnerUid);
        final isDoodling = status.isActivelyDoodlingAt(_now);
        final isOnline = status.isOnlineAt(_now);

        if (isDoodling) {
          return _DoodleBanner(
            name: partnerName,
            elapsed: status.timeSinceLastDoodle(_now),
            isActive: true,
          );
        }

        if (isOnline) {
          return _DoodleBanner(
            name: partnerName,
            elapsed: Duration.zero,
            isActive: false,
            subtitle: 'Not active doodling',
          );
        }

        return const SizedBox.shrink();
      },
    );
  }
}

class _DoodleBanner extends StatelessWidget {
  final String name;
  final Duration elapsed;
  final bool isActive;
  final String? subtitle;

  const _DoodleBanner({
    required this.name,
    required this.elapsed,
    required this.isActive,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final accent = isActive
        ? AppTheme.warmAmber
        : AppTheme.roseQuartz.withValues(alpha: 0.7);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.velvet.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.4), width: 1.0),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: accent.withValues(alpha: 0.25),
                  blurRadius: 14,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          EverglowPresenceDot(
            state: isActive ? PresenceState.doodle : PresenceState.online,
            size: 10,
          ),
          const SizedBox(width: 8),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isActive
                        ? '$name is doodling'
                        : subtitle ?? '$name is here',
                    style: AppTypography.outfitBold.copyWith(fontSize: 12),
                  ),
                  if (isActive) ...[
                    const SizedBox(width: 6),
                    Text(
                      '✨',
                      style: AppTypography.outfitWhite.copyWith(fontSize: 12),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatElapsed(elapsed),
                      style: AppTypography.outfitHeading.copyWith(
                        color: accent,
                        fontSize: 12,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ],
              ),
              if (isActive)
                Text(
                  'active doodle',
                  style: AppTypography.outfitWhite.copyWith(
                    color: AppTheme.petalWhite.withValues(alpha: 0.75),
                    fontSize: 9,
                    letterSpacing: 0.8,
                  ),
                )
              else
                Text(
                  'not active doodling',
                  style: AppTypography.outfitWhite.copyWith(
                    color: AppTheme.petalWhite.withValues(alpha: 0.7),
                    fontSize: 9,
                    letterSpacing: 0.6,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatElapsed(Duration d) {
    if (d.inSeconds < 60) return '${d.inSeconds}s';
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return s == 0 ? '${m}m' : '${m}m ${s}s';
  }
}
