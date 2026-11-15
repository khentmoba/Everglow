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

class DailyBloom extends StatefulWidget {
  const DailyBloom({super.key});

  @override
  State<DailyBloom> createState() => _DailyBloomState();
}

class _DailyBloomState extends State<DailyBloom> {
  bool _showTooltip = false;
  double _scale = 1.0;
  bool _gardenReported = false;

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
        bool isCouple = false;
        String? currentUser;
        try {
          isCouple =
              context.select<AuthService, bool>((a) => a.isCoupleUser);
          currentUser =
              context.select<AuthService, String?>((a) => a.currentUser);
        } catch (_) {
          // Optional in widget tests pumped without an AuthService.
        }
        AuthService? auth;
        try {
          auth = context.read<AuthService>();
        } catch (_) {
          auth = null;
        }
        final coupleAuth = auth;

        final stats = provider.stats;
        if (!_gardenReported && (stats != null || provider.hasSettledError)) {
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

        if (coupleAuth == null || !isCouple || currentUser == null) {
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
