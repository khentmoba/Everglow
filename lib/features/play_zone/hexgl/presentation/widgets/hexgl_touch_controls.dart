import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../core/theme/app_theme.dart';

typedef HexGLInputCallback = void Function(String key, bool value);

class HexGLTouchControls extends StatefulWidget {
  const HexGLTouchControls({super.key, required this.onInput});

  final HexGLInputCallback onInput;

  @override
  State<HexGLTouchControls> createState() => _HexGLTouchControlsState();
}

class _HexGLTouchControlsState extends State<HexGLTouchControls> {
  static const double _deadZone = 0.18;
  static const double _maxSteerDistance = 220.0; // px from center for full lock

  // left-side steering
  int? _steerPointer;
  double _steerX = 0.0;

  // right-side boost / drift
  int? _boostPointer;
  int? _driftPointer;

  void _sendInput(String key, bool value) {
    widget.onInput(key, value);
  }

  void _updateSteer(Offset localPos, double halfWidth, Size size) {
    final center = halfWidth / 2;
    final delta = (localPos.dx - center).clamp(-_maxSteerDistance, _maxSteerDistance);
    final normalized = delta / _maxSteerDistance; // -1..1
    final absNorm = normalized.abs();
    if (absNorm < _deadZone) {
      if (_steerX != 0.0) {
        _steerX = 0.0;
        _sendInput('left', false);
        _sendInput('right', false);
      }
      return;
    }
    final sign = normalized.isNegative ? -1.0 : 1.0;
    final scaled = ((absNorm - _deadZone) / (1.0 - _deadZone)) * sign;
    if ((scaled - _steerX).abs() < 0.01) return;
    _steerX = scaled;
    _sendInput('left', scaled < 0);
    _sendInput('right', scaled > 0);
  }

  void _onPointerDown(PointerDownEvent event) {
    final size = context.size ?? Size.zero;
    if (size == Size.zero) return;
    final halfWidth = size.width / 2;
    if (event.localPosition.dx < halfWidth) {
      _steerPointer = event.pointer;
      _updateSteer(event.localPosition, halfWidth, size);
    } else {
      // Right half: split vertically into boost (top) and drift (bottom)
      final halfHeight = size.height / 2;
      if (event.localPosition.dy < halfHeight) {
        _boostPointer = event.pointer;
        if (_boostPointer != null && _driftPointer == null) {
          _sendInput('customBoost', true);
        }
      } else {
        _driftPointer = event.pointer;
        if (_driftPointer != null && _boostPointer == null) {
          _sendInput('drift', true);
        }
      }
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_steerPointer == event.pointer) {
      final size = context.size ?? Size.zero;
      if (size == Size.zero) return;
      _updateSteer(event.localPosition, size.width / 2, size);
    }
  }

  void _onPointerUp(PointerEvent event) {
    if (_steerPointer == event.pointer) {
      _steerPointer = null;
      if (_steerX != 0.0) {
        _steerX = 0.0;
        _sendInput('left', false);
        _sendInput('right', false);
      }
    } else if (_boostPointer == event.pointer) {
      _boostPointer = null;
      _sendInput('customBoost', false);
    } else if (_driftPointer == event.pointer) {
      _driftPointer = null;
      _sendInput('drift', false);
    }
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _onPointerUp(event);
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.basic,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: _onPointerDown,
        onPointerMove: _onPointerMove,
        onPointerUp: _onPointerUp,
        onPointerCancel: _onPointerCancel,
        child: LayoutBuilder(builder: (context, constraints) {
          final isBoost = _boostPointer != null;
          final isDrift = _driftPointer != null;
          return Stack(
            children: [
              // Left side steering indicator
              Positioned(
                left: 16,
                bottom: 24,
                child: _SteerIndicator(value: _steerX, size: 96),
              ),

              // Right side drift button (bottom, large)
              Positioned(
                right: 16,
                bottom: 24,
                child: _HoldButton(
                  size: 124,
                  icon: Icons.swap_horiz_rounded,
                  label: 'DRIFT',
                  color: AppTheme.softLavender,
                  active: isDrift,
                  onChanged: (pressed) {
                    HapticFeedback.lightImpact();
                    _sendInput('drift', pressed);
                  },
                ),
              ),

              // Right side boost button (above drift, smaller)
              Positioned(
                right: 28,
                bottom: 24 + 124 + 12,
                child: _HoldButton(
                  size: 84,
                  icon: Icons.bolt_rounded,
                  label: 'BOOST',
                  color: AppTheme.warmAmber,
                  active: isBoost,
                  onChanged: (pressed) {
                    HapticFeedback.mediumImpact();
                    _sendInput('customBoost', pressed);
                  },
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

class _HoldButton extends StatelessWidget {
  const _HoldButton({
    required this.size,
    required this.icon,
    required this.label,
    required this.color,
    required this.active,
    required this.onChanged,
  });

  final double size;
  final IconData icon;
  final String label;
  final Color color;
  final bool active;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => onChanged(true),
      onTapUp: (_) => onChanged(false),
      onTapCancel: () => onChanged(false),
      onPanStart: (_) => onChanged(true),
      onPanEnd: (_) => onChanged(false),
      onPanCancel: () => onChanged(false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: active ? 0.95 : 0.55),
              color.withValues(alpha: active ? 0.65 : 0.25),
            ],
          ),
          border: Border.all(
            color: color.withValues(alpha: active ? 0.9 : 0.45),
            width: active ? 3.0 : 2.0,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: active ? 0.55 : 0.18),
              blurRadius: active ? 22 : 10,
              spreadRadius: active ? 2 : 0,
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: AppTheme.petalWhite,
              size: size * 0.4,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'BebasNeue',
                color: AppTheme.petalWhite.withValues(alpha: 0.9),
                fontSize: size * 0.13,
                letterSpacing: 1.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SteerIndicator extends StatelessWidget {
  const _SteerIndicator({required this.value, required this.size});
  final double value;
  final double size;

  @override
  Widget build(BuildContext context) {
    final clamped = value.clamp(-1.0, 1.0);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppTheme.moonlight.withValues(alpha: 0.08),
        border: Border.all(
          color: AppTheme.moonlight.withValues(alpha: 0.18),
          width: 1.2,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            Icons.touch_app_rounded,
            color: AppTheme.petalWhite.withValues(alpha: 0.18),
            size: size * 0.45,
          ),
          Transform.translate(
            offset: Offset(clamped * (size * 0.32), 0),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 80),
              width: size * 0.35,
              height: size * 0.35,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.softLavender.withValues(alpha: 0.85),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.softLavender.withValues(alpha: 0.5),
                    blurRadius: 12,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
