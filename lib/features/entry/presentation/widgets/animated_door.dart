import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

/// The Everglow entry door.
///
/// An arched double-tone door with carved bevels, a brass lever and a
/// keyhole escutcheon. It breathes softly on the gateway, then swings
/// open with a shaft of light when the passcode unlocks.
class AnimatedDoor extends StatefulWidget {
  final bool isUnlocked;
  final bool isError;
  final bool isRevealing;
  final bool isLoaded;
  final Widget? keypad;
  final VoidCallback? onEntranceComplete;

  const AnimatedDoor({
    super.key,
    this.isUnlocked = false,
    this.isError = false,
    this.isRevealing = false,
    this.isLoaded = false,
    this.keypad,
    this.onEntranceComplete,
  });

  @override
  State<AnimatedDoor> createState() => _AnimatedDoorState();
}

class _AnimatedDoorState extends State<AnimatedDoor>
    with TickerProviderStateMixin {
  late final AnimationController _entranceController;
  late final AnimationController _swingController;
  late final AnimationController _handleController;
  late final AnimationController _zoomController;
  late final AnimationController _breatheController;

  late final Animation<double> _entrance;
  late final Animation<double> _swing;
  late final Animation<double> _handle;
  late final Animation<double> _zoom;
  Timer? _entranceFallbackTimer;
  bool _entranceCompleted = false;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      duration: const Duration(milliseconds: 1400),
      vsync: this,
    );
    _swingController = AnimationController(
      duration: const Duration(milliseconds: 1700),
      vsync: this,
    );
    _handleController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );
    _zoomController = AnimationController(
      duration: const Duration(milliseconds: 1100),
      vsync: this,
    );
    _breatheController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);

    _entrance = CurvedAnimation(
      parent: _entranceController,
      curve: AppMotion.orLinear(const Cubic(0.16, 1.0, 0.3, 1.0)),
    );
    _swing = CurvedAnimation(
      parent: _swingController,
      curve: AppMotion.orLinear(Curves.easeInOutCubic),
    );
    _handle = CurvedAnimation(
      parent: _handleController,
      curve: AppMotion.orLinear(const Cubic(0.34, 1.56, 0.64, 1.0)),
    );
    _zoom = CurvedAnimation(
      parent: _zoomController,
      curve: AppMotion.orLinear(Curves.easeInQuint),
    );

    _entranceController.forward().then((_) => _completeEntrance());
    // Some Android emulators/vendors never deliver the animation ticker
    // future reliably. Fall back so the keypad always appears.
    _entranceFallbackTimer = Timer(
      const Duration(milliseconds: 1800),
      _completeEntrance,
    );
  }

  void _completeEntrance() {
    if (_entranceCompleted) return;
    _entranceCompleted = true;
    if (mounted && widget.onEntranceComplete != null) {
      widget.onEntranceComplete!();
    }
  }

  @override
  void didUpdateWidget(AnimatedDoor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isUnlocked && !oldWidget.isUnlocked) {
      _unlockSequence();
    }
    if (widget.isRevealing && !oldWidget.isRevealing) {
      _zoomController.forward();
    }
  }

  Future<void> _unlockSequence() async {
    await _handleController.forward();
    await Future.delayed(const Duration(milliseconds: 180));
    await _swingController.forward();
  }

  @override
  void dispose() {
    _entranceFallbackTimer?.cancel();
    _entranceController.dispose();
    _swingController.dispose();
    _handleController.dispose();
    _zoomController.dispose();
    _breatheController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewport = MediaQuery.sizeOf(context);
    final scale = math.min(
      1.0,
      math.min((viewport.width - 24) / 330, (viewport.height - 48) / 560),
    );
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: Listenable.merge([
          _entranceController,
          _swingController,
          _zoomController,
          _breatheController,
        ]),
        builder: (context, _) {
          final zoomScale = 1.0 + (4.0 * _zoom.value);
          final breathe = 1.0 + (0.012 * _breatheController.value);
          final entranceBounce = 0.92 + (0.08 * _entrance.value);

          return Transform.scale(
            scale: entranceBounce * zoomScale * breathe,
            child: Opacity(
              opacity: (_entrance.value * (1.0 - _zoom.value)).clamp(0.0, 1.0),
              child: Transform.scale(
                scale: scale,
                child: SizedBox(
                  width: 330,
                  height: 560,
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      // Soft halo behind the whole door.
                      _buildHalo(),
                      // Twinkling sparkles.
                      _buildSparkles(),
                      // Light that pours out while the door swings open.
                      if (widget.isUnlocked) _buildLightBloom(),
                      // The frame stays put while the panel swings.
                      _buildDoorFrame(),
                      // The swinging panel.
                      Transform(
                        alignment: Alignment.centerLeft,
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, 0.001)
                          ..rotateY(-math.pi / 2 * _swing.value),
                        child: _buildDoorPanel(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Layers ────────────────────────────────────────────────────────────────

  Widget _buildHalo() {
    return Positioned.fill(
      child: IgnorePointer(
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.deepRose.withValues(
                  alpha: 0.22 + (0.08 * _breatheController.value),
                ),
                blurRadius: 90,
                spreadRadius: 24,
              ),
              BoxShadow(
                color: AppColors.blushGold.withValues(alpha: 0.10),
                blurRadius: 140,
                spreadRadius: 40,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSparkles() {
    return Positioned.fill(
      child: IgnorePointer(
        child: CustomPaint(
          painter: _SparklePainter(progress: _breatheController.value),
        ),
      ),
    );
  }

  Widget _buildLightBloom() {
    return AnimatedBuilder(
      animation: _swingController,
      builder: (context, _) {
        final t = _swing.value;
        return Center(
          child: Container(
            width: 300 * (0.35 + (0.65 * t)),
            height: 560 * (0.45 + (0.55 * t)),
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0.2, 0),
                radius: 0.9,
                colors: [
                  AppColors.blushGold.withValues(alpha: 0.85 * t),
                  AppColors.auroraRose.withValues(alpha: 0.35 * t),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.45, 1.0],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.petalWhite.withValues(alpha: 0.5 * t),
                  blurRadius: 70,
                  spreadRadius: 30,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDoorFrame() {
    return Positioned.fill(
      child: ClipPath(
        clipper: const _ArchClipper(),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.blushGold.withValues(alpha: 0.9),
                AppColors.velvet,
                AppColors.twilight,
              ],
              stops: const [0.0, 0.28, 1.0],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(7),
            child: ClipPath(
              clipper: const _ArchClipper(),
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.inkDeep, AppColors.twilight],
                  ),
                  border: Border.all(
                    color: AppColors.moonlight.withValues(alpha: 0.22),
                    width: 1.2,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDoorPanel() {
    final error = widget.isError;
    return SizedBox(
      width: 316,
      height: 546,
      child: ClipPath(
        clipper: const _ArchClipper(),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                if (error) ...[
                  AppColors.error.withValues(alpha: 0.75),
                  AppColors.deepRose.withValues(alpha: 0.9),
                ] else ...[
                  AppColors.velvet,
                  AppColors.twilight,
                ],
              ],
              stops: [0.0, 1.0 - (0.45 * _swing.value)],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: 0.55 - (0.25 * _swing.value),
                ),
                blurRadius: 26,
                offset: Offset(
                  12 * (1 - _swing.value),
                  12 * (1 - _swing.value),
                ),
              ),
              BoxShadow(
                color: error
                    ? AppColors.error.withValues(alpha: 0.35)
                    : AppColors.deepRose.withValues(alpha: 0.25),
                blurRadius: 40,
                spreadRadius: -8,
              ),
            ],
          ),
          child: Stack(
            children: [
              // Carved bevels.
              Positioned.fill(child: _buildPanelBevels()),
              // Engraved nameplate.
              Positioned(top: 34, left: 0, right: 0, child: _buildNameplate()),
              Positioned(
                top: 92,
                left: 0,
                right: 0,
                child: Text(
                  'Khent & Clair',
                  textAlign: TextAlign.center,
                  style: AppTypography.handwrittenBody().copyWith(
                    fontSize: 15,
                    color: AppColors.blushGold.withValues(alpha: 0.9),
                    height: 1.0,
                  ),
                ),
              ),
              // Keypad.
              Center(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 64, 44, 42),
                  child: widget.keypad ?? const SizedBox.shrink(),
                ),
              ),
              // Brass lever.
              Positioned(
                right: 14,
                top: 262,
                child: AnimatedBuilder(
                  animation: _handleController,
                  builder: (context, _) {
                    return Transform.rotate(
                      angle: _handle.value * (math.pi / 5),
                      child: _buildLever(),
                    );
                  },
                ),
              ),
              // Keyhole escutcheon below the lever.
              Positioned(right: 38, top: 330, child: _buildEscutcheon()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPanelBevels() {
    return Column(
      children: [
        Expanded(flex: 3, child: _bevelBox(topArch: true)),
        Expanded(flex: 1, child: _bevelBox(topArch: false)),
        Expanded(flex: 3, child: _bevelBox(topArch: true)),
      ],
    );
  }

  Widget _bevelBox({required bool topArch}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 34, vertical: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(topArch ? 26 : 10),
          bottom: const Radius.circular(10),
        ),
        border: Border.all(
          color: AppColors.moonlight.withValues(alpha: 0.18),
          width: 1,
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.moonlight.withValues(alpha: 0.09),
            Colors.transparent,
            AppColors.inkDeep.withValues(alpha: 0.28),
          ],
        ),
      ),
    );
  }

  Widget _buildNameplate() {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            colors: [
              AppColors.blushGold.withValues(alpha: 0.85),
              AppColors.auroraGold.withValues(alpha: 0.65),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.blushGold.withValues(alpha: 0.35),
              blurRadius: 18,
            ),
          ],
        ),
        child: Text(
          'EVERGLOW',
          style: AppTypography.labelMedium().copyWith(
            color: AppColors.inkDeep,
            fontWeight: FontWeight.w800,
            letterSpacing: 3.4,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildLever() {
    return SizedBox(
      width: 78,
      height: 40,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.centerLeft,
        children: [
          // Rosette.
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.auroraGold, AppColors.blushGold],
              ),
              border: Border.all(
                color: AppColors.petalWhite.withValues(alpha: 0.35),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 6,
                  offset: const Offset(1, 2),
                ),
                BoxShadow(
                  color: AppColors.auroraGold.withValues(alpha: 0.5),
                  blurRadius: 14,
                ),
              ],
            ),
            child: Center(
              child: Container(
                width: 10,
                height: 14,
                decoration: BoxDecoration(
                  color: AppColors.inkDeep.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
          // Lever arm.
          Positioned(
            left: 20,
            child: Container(
              width: 60,
              height: 15,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [AppColors.auroraGold, AppColors.blushGold],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.45),
                    blurRadius: 7,
                    offset: const Offset(2, 3),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEscutcheon() {
    return Container(
      width: 46,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.blushGold, AppColors.auroraGold],
        ),
        border: Border.all(color: AppColors.petalWhite.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 6,
            offset: const Offset(1, 2),
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: 16,
          height: 22,
          decoration: BoxDecoration(
            color: AppColors.inkDeep.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: 7,
              height: 8,
              margin: const EdgeInsets.only(bottom: 3),
              decoration: const BoxDecoration(
                color: AppColors.inkDeep,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(4)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Arched door silhouette.
class _ArchClipper extends CustomClipper<Path> {
  const _ArchClipper();

  @override
  Path getClip(Size size) {
    final r = size;
    final archRadius = math.min(r.width / 2, r.height * 0.24);
    return Path()
      ..moveTo(0, r.height)
      ..lineTo(0, archRadius)
      ..quadraticBezierTo(0, 0, archRadius, 0)
      ..lineTo(r.width - archRadius, 0)
      ..quadraticBezierTo(r.width, 0, r.width, archRadius)
      ..lineTo(r.width, r.height)
      ..close();
  }

  @override
  bool shouldReclip(_ArchClipper oldClipper) => false;
}

/// Twinkling gold dust drifting in front of the door.
class _SparklePainter extends CustomPainter {
  final double progress;

  _SparklePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (int i = 0; i < 26; i++) {
      final seed = i * 137.0;
      final x = ((seed * 1.61) % 1.0) * size.width;
      final y = ((seed * 3.71) % 1.0) * size.height;
      final twinkle =
          0.25 + (0.55 * (0.5 + 0.5 * math.sin(progress * math.pi * 4 + seed)));
      final radius = 0.8 + ((seed % 1.0) * 1.4);
      paint.color = AppColors.auroraGold.withValues(alpha: twinkle * 0.55);
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(_SparklePainter oldDelegate) =>
      oldDelegate.progress != progress;
}
