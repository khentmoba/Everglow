import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_theme.dart';

/// A reusable countdown timer widget that shows time remaining
/// until a target [DateTime] in the Dusk Petal aesthetic.
///
/// Updates every second when the target is within 24 hours,
/// every minute otherwise.
class EverglowCountdown extends StatefulWidget {
  /// The target date/time to count down to.
  final DateTime target;

  /// Optional label shown above the countdown (e.g. "Anniversary", "Trip").
  final String? label;

  /// Optional emoji shown next to the label.
  final String? emoji;

  /// Whether to show seconds (default true when < 24h away).
  final bool? showSeconds;

  /// Layout: compact (single row) or full (multi-unit grid).
  final EverglowCountdownStyle style;

  const EverglowCountdown({
    super.key,
    required this.target,
    this.label,
    this.emoji,
    this.showSeconds,
    this.style = EverglowCountdownStyle.compact,
  });

  @override
  State<EverglowCountdown> createState() => _EverglowCountdownState();
}

enum EverglowCountdownStyle { compact, full }

class _EverglowCountdownState extends State<EverglowCountdown> {
  Timer? _timer;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _updateRemaining();
    _startTimer();
  }

  @override
  void didUpdateWidget(EverglowCountdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.target != widget.target) {
      _timer?.cancel();
      _updateRemaining();
      _startTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _updateRemaining() {
    final now = DateTime.now();
    if (!mounted) return;
    setState(() {
      _remaining = widget.target.isAfter(now)
          ? widget.target.difference(now)
          : Duration.zero;
    });
  }

  void _startTimer() {
    final isClose = _remaining.inHours < 24;
    final interval = isClose
        ? const Duration(seconds: 1)
        : const Duration(minutes: 1);

    _timer = Timer.periodic(interval, (_) {
      if (!mounted) return;
      _updateRemaining();
      // Switch to per-second when we get close
      if (_remaining.inHours < 24 && _timer != null) {
        _timer?.cancel();
        _timer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (!mounted) return;
          _updateRemaining();
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_remaining == Duration.zero) {
      return _buildArrived();
    }

    return widget.style == EverglowCountdownStyle.compact
        ? _buildCompact()
        : _buildFull();
  }

  Widget _buildArrived() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.deepRose.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.blushGold.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.emoji != null) ...[
            Text(widget.emoji!, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
          ],
          Text(
            widget.label ?? 'It\'s time! 🎉',
            style: AppTypography.outfitHeading.copyWith(
              fontSize: 14,
              color: AppTheme.blushGold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompact() {
    final days = _remaining.inDays;
    final hours = _remaining.inHours % 24;
    final minutes = _remaining.inMinutes % 60;
    final seconds = _remaining.inSeconds % 60;
    final showSec = widget.showSeconds ?? (_remaining.inHours < 24);

    String text;
    if (days > 0) {
      text = '${days}d ${hours}h ${minutes}m';
    } else if (hours > 0) {
      text = showSec
          ? '${hours}h ${minutes}m ${seconds}s'
          : '${hours}h ${minutes}m';
    } else {
      text = '${minutes}m ${seconds}s';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.velvet.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.moonlight.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.emoji != null) ...[
            Text(widget.emoji!, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
          ],
          if (widget.label != null) ...[
            Text(
              widget.label!,
              style: AppTypography.outfitWhite.copyWith(
                fontSize: 12,
                color: AppTheme.roseQuartz.withValues(alpha: 0.7),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Text(
            text,
            style: AppTypography.outfitHeading.copyWith(
              fontSize: 13,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFull() {
    final days = _remaining.inDays;
    final hours = _remaining.inHours % 24;
    final minutes = _remaining.inMinutes % 60;
    final seconds = _remaining.inSeconds % 60;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.label != null) ...[
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.emoji != null) ...[
                Text(widget.emoji!, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
              ],
              Text(
                widget.label!,
                style: AppTypography.cormorantBold.copyWith(fontSize: 18),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _UnitBlock(value: days, unit: 'DAYS'),
            _Separator(),
            _UnitBlock(value: hours, unit: 'HRS'),
            _Separator(),
            _UnitBlock(value: minutes, unit: 'MIN'),
            if (widget.showSeconds ?? true) ...[
              _Separator(),
              _UnitBlock(value: seconds, unit: 'SEC'),
            ],
          ],
        ),
      ],
    );
  }
}

class _UnitBlock extends StatelessWidget {
  final int value;
  final String unit;

  const _UnitBlock({required this.value, required this.unit});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.velvet.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.moonlight.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Text(
            value.toString().padLeft(2, '0'),
            style: AppTypography.outfitHeading.copyWith(fontSize: 22),
          ),
          const SizedBox(height: 2),
          Text(
            unit,
            style: AppTypography.outfitBold.copyWith(
              fontSize: 9,
              color: AppTheme.roseQuartz.withValues(alpha: 0.6),
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _Separator extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Text(
        ':',
        style: AppTypography.outfitHeading.copyWith(
          fontSize: 18,
          color: AppTheme.blushGold.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}
