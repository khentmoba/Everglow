import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/garden_provider.dart';
import '../../data/models/garden_stats.dart';
import '../../data/models/plant_type.dart';
import 'garden_plant_view.dart';
import 'garden_weather_overlay.dart';
import 'plant_picker_sheet.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/services/auth_service.dart';
import '../../../dashboard/presentation/widgets/dashboard_load_tracker.dart';

part 'daily_bloom_cards.dart';
part 'daily_bloom_scene.dart';
part 'daily_bloom_stats.dart';

/// The living heart of the dashboard: Khent & Clair's plants side by side
/// in a night-garden sanctuary card — moonlight glow, stars, seasonal
/// weather, growth dots, glowing stats, and two clear actions.
///
/// Clair sits on the left, Khent on the right. Cinema-only profiles and
/// tests without an [AuthService] fall back to the single-garden view.
///
/// No panel-level tap: each plant (tooltip), Change (sheet), and Our Garden
/// (route) each own their gesture, so nested taps never double-fire.
class DailyBloom extends StatefulWidget {
  const DailyBloom({super.key});

  @override
  State<DailyBloom> createState() => _DailyBloomState();
}

class _DailyBloomState extends State<DailyBloom> {
  bool _showTooltip = false;
  double _scale = 1.0;
  bool _gardenReported = false;

  /// Which side's tooltip is open in dual view: 'clair', 'khent', or null.
  String? _dualTooltipSide;
  String? _dualPulseSide;

  void _toggleTooltip() {
    setState(() => _showTooltip = !_showTooltip);
    if (_showTooltip) {
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _showTooltip = false);
      });
    }
  }

  void _triggerPulse() {
    setState(() => _scale = 1.2);
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) setState(() => _scale = 1.0);
    });
  }

  void _toggleDualTooltip(String side) {
    setState(() => _dualTooltipSide = _dualTooltipSide == side ? null : side);
    if (_dualTooltipSide != null) {
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _dualTooltipSide = null);
      });
    }
  }

  void _triggerDualPulse(String side) {
    setState(() => _dualPulseSide = side);
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) setState(() => _dualPulseSide = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<GardenProvider>(
      builder: (context, provider, child) {
        // Auth is optional here: widget tests pump DailyBloom with only a
        // GardenProvider. Without a couple session we render the classic
        // single-garden card.
        AuthService? auth;
        try {
          auth = context.watch<AuthService>();
        } catch (_) {
          auth = null;
        }
        final coupleAuth = auth;

        final stats = provider.stats;
        // First-screen progress: the garden has settled (stats or final
        // error), so the load veil can count us. Reported post-frame —
        // notifyListeners must not fire during build — and retried each
        // build until a tracker accepts it (cards can render in tests
        // or routes without one). Own stats settle the veil; the partner
        // stream may lag a beat behind without holding first paint.
        if (!_gardenReported && (stats != null || provider.hasError)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || _gardenReported) return;
            try {
              context.read<DashboardLoadTracker>().mark(
                DashboardLoadSignal.garden,
              );
              _gardenReported = true;
            } catch (_) {}
          });
        }

        if (coupleAuth == null ||
            !coupleAuth.isCoupleUser ||
            coupleAuth.currentUser == null) {
          return _SingleGardenCard(
            provider: provider,
            stats: stats,
            showTooltip: _showTooltip,
            scale: _scale,
            onPlantTap: () {
              _toggleTooltip();
              _triggerPulse();
            },
          );
        }

        return _DualGardenCard(
          provider: provider,
          auth: coupleAuth,
          tooltipSide: _dualTooltipSide,
          pulseSide: _dualPulseSide,
          onPlantTap: (side) {
            _toggleDualTooltip(side);
            _triggerDualPulse(side);
          },
        );
      },
    );
  }
}
