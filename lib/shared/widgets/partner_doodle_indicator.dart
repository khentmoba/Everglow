import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import 'package:provider/provider.dart';
import '../../core/models/presence_status.dart';
import '../../core/theme/app_typography.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/presence_service.dart';
import 'everglow/everglow_presence_dot.dart';

class PartnerDoodleIndicator extends StatefulWidget {
  const PartnerDoodleIndicator({super.key});

  @override
  State<PartnerDoodleIndicator> createState() => _PartnerDoodleIndicatorState();
}

class _PartnerDoodleIndicatorState extends State<PartnerDoodleIndicator>
    with WidgetsBindingObserver {
  Timer? _ticker;
  DateTime _now = DateTime.now();
  String? _presenceUid;
  Stream<PresenceStatus>? _presenceStream;
  bool _appActive = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _appActive = lifecycle == null || lifecycle == AppLifecycleState.resumed;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncTicker();
  }

  void _syncTicker() {
    _ticker?.cancel();
    _ticker = null;
    if (!_appActive || !TickerMode.valuesOf(context).enabled) return;
    _now = DateTime.now();
    // Freshness ticker: doodle state flips on 15s touch windows, and the
    // widget only shows active/idle — 1s granularity is plenty. The
    // previous 250ms setState rebuilt this subtree (StreamBuilder
    // included) 4x per second for the whole dashboard lifetime.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appActive = state == AppLifecycleState.resumed;
    _syncTicker();
    if (_appActive) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // select() instead of watch(): partner fields change rarely, and a
    // full watch rebuilds this indicator (and re-evaluates the stream
    // builder below) on every unrelated auth notify.
    final partnerUid = context.select<AuthService, String?>(
      (a) => a.partnerUid,
    );
    final partnerName = context.select<AuthService, String>(
      (a) => a.partnerName,
    );
    final presence = context.read<PresenceService>();

    if (partnerUid == null) {
      return const SizedBox.shrink();
    }

    if (_presenceUid != partnerUid) {
      _presenceUid = partnerUid;
      _presenceStream = presence.watchPresence(partnerUid);
    }
    return StreamBuilder<PresenceStatus>(
      stream: _presenceStream,
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
        ? AppColors.warmAmber
        : AppColors.roseQuartz.withValues(alpha: 0.7);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.velvet.withValues(alpha: 0.78),
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
                    color: AppColors.petalWhite.withValues(alpha: 0.75),
                    fontSize: 9,
                    letterSpacing: 0.8,
                  ),
                )
              else
                Text(
                  'not active doodling',
                  style: AppTypography.outfitWhite.copyWith(
                    color: AppColors.petalWhite.withValues(alpha: 0.7),
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
