import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:everglow/core/models/presence_status.dart';
import 'package:everglow/core/theme/app_theme.dart';
import 'package:everglow/services/auth_service.dart';
import 'package:everglow/services/presence_service.dart';

class PartnerPresenceIndicator extends StatefulWidget {
  final TextStyle? textStyle;
  final Color? dotColor;
  final double dotSize;
  final bool showDot;

  const PartnerPresenceIndicator({
    super.key,
    this.textStyle,
    this.dotColor,
    this.dotSize = 8.0,
    this.showDot = true,
  });

  @override
  State<PartnerPresenceIndicator> createState() =>
      _PartnerPresenceIndicatorState();
}

class _PartnerPresenceIndicatorState extends State<PartnerPresenceIndicator> {
  Timer? _ticker;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
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
      return _buildText(
        context,
        'Partner link unavailable · re-login to sync',
        dim: true,
      );
    }

    return StreamBuilder<PresenceStatus>(
      stream: presence.watchPresence(partnerUid),
      builder: (context, snapshot) {
        final status = snapshot.data ?? PresenceStatus.empty(partnerUid);
        final isOnline = status.isOnlineAt(_now);

        if (isOnline) {
          return _buildRow(
            context,
            dot: _Dot(color: const Color(0xFF4ADE80), size: widget.dotSize, pulse: true),
            label: '$partnerName is active',
            color: const Color(0xFF4ADE80),
            dim: false,
          );
        }

        if (!status.hasEverBeenSeen) {
          return _buildText(
            context,
            '$partnerName · not online yet',
            dim: true,
          );
        }

        final ago = _formatAgo(status.timeSinceLastSeen(_now));
        return _buildRow(
          context,
          dot: _Dot(color: AppTheme.roseQuartz.withValues(alpha: 0.5), size: widget.dotSize),
          label: 'Active $ago ago',
          color: AppTheme.roseQuartz.withValues(alpha: 0.85),
          dim: false,
        );
      },
    );
  }

  Widget _buildRow(
    BuildContext context, {
    required _Dot dot,
    required String label,
    required Color color,
    required bool dim,
  }) {
    final style = (widget.textStyle ??
            GoogleFonts.outfit(
              color: AppTheme.roseQuartz.withValues(alpha: 0.5),
              fontSize: 10,
            ))
        .copyWith(
      color: dim ? AppTheme.roseQuartz.withValues(alpha: 0.5) : color,
      fontWeight: dim ? FontWeight.w400 : FontWeight.w500,
    );

    if (!widget.showDot) {
      return Text(label, style: style);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        dot,
        const SizedBox(width: 6),
        Text(label, style: style),
      ],
    );
  }

  Widget _buildText(BuildContext context, String text, {required bool dim}) {
    return Text(
      text,
      style: widget.textStyle ??
          GoogleFonts.outfit(
            color: AppTheme.roseQuartz.withValues(alpha: 0.5),
            fontSize: 10,
          ),
    );
  }

  String _formatAgo(Duration d) {
    if (d.inSeconds < 60) return '${d.inSeconds}s';
    final minutes = d.inMinutes;
    if (minutes < 60) {
      final secs = d.inSeconds % 60;
      return secs == 0 ? '${minutes}m' : '${minutes}m ${secs}s';
    }
    final hours = d.inHours;
    final mins = d.inMinutes % 60;
    if (hours < 24) {
      return mins == 0 ? '${hours}h' : '${hours}h ${mins}m';
    }
    final days = d.inDays;
    final remHours = d.inHours % 24;
    if (days < 7) {
      return remHours == 0 ? '${days}d' : '${days}d ${remHours}h';
    }
    return '${days}d';
  }
}

class _Dot extends StatefulWidget {
  final Color color;
  final double size;
  final bool pulse;

  const _Dot({
    required this.color,
    required this.size,
    this.pulse = false,
  });

  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    if (widget.pulse) {
      _ctrl.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant _Dot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pulse && !_ctrl.isAnimating) {
      _ctrl.repeat(reverse: true);
    } else if (!widget.pulse && _ctrl.isAnimating) {
      _ctrl.stop();
      _ctrl.value = 0;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final glow = widget.pulse ? 0.35 + (_ctrl.value * 0.55) : 0.0;
        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: widget.color,
            shape: BoxShape.circle,
            boxShadow: widget.pulse
                ? [
                    BoxShadow(
                      color: widget.color.withValues(alpha: glow),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
        );
      },
    );
  }
}
