import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:everglow/core/theme/app_typography.dart';
import 'package:everglow/core/theme/app_motion.dart';
import 'package:everglow/core/theme/app_colors.dart';

/// Elegant glass passcode keypad with gold accents and a shake-on-error.
class PasscodeInput extends StatefulWidget {
  final String input;
  final Function(String) onDigitPressed;
  final VoidCallback onBackspace;
  final bool isError;

  const PasscodeInput({
    super.key,
    required this.input,
    required this.onDigitPressed,
    required this.onBackspace,
    this.isError = false,
  });

  @override
  State<PasscodeInput> createState() => _PasscodeInputState();
}

class _PasscodeInputState extends State<PasscodeInput>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 520),
      vsync: this,
    );
    _shakeAnimation =
        Tween<double>(
            begin: 0,
            end: 13,
          ).chain(CurveTween(curve: Curves.easeInOut)).animate(_shakeController)
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed) {
              _shakeController.reverse();
            }
          });
  }

  @override
  void didUpdateWidget(PasscodeInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isError && !oldWidget.isError) {
      _shakeController.forward(from: 0);
      HapticFeedback.vibrate();
    }
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _shakeAnimation,
        builder: (context, _) {
          final wave = math.sin(_shakeAnimation.value / 13 * math.pi);
          return Transform.translate(
            offset: Offset(wave * _shakeAnimation.value, 0),
            child: Column(
              children: [
                _buildDots(),
                const SizedBox(height: 42),
                _buildNumPad(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (index) {
        final isFilled = index < widget.input.length;
        return AnimatedContainer(
          duration: AppMotion.orZero(const Duration(milliseconds: 220)),
          curve: AppMotion.easeOutStrong,
          margin: const EdgeInsets.symmetric(horizontal: 13),
          width: isFilled ? 26 : 16,
          height: 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.isError
                ? AppColors.error.withValues(alpha: 0.85)
                : (isFilled
                      ? AppColors.auroraGold
                      : AppColors.moonlight.withValues(alpha: 0.08)),
            boxShadow: isFilled
                ? [
                    BoxShadow(
                      color:
                          (widget.isError
                                  ? AppColors.error
                                  : AppColors.auroraGold)
                              .withValues(alpha: 0.7),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ]
                : const [],
            border: Border.all(
              color: isFilled
                  ? (widget.isError ? AppColors.error : AppColors.auroraGold)
                  : AppColors.moonlight.withValues(alpha: 0.25),
              width: 1.6,
            ),
          ),
        );
      }),
    );
  }

  Widget _buildNumPad() {
    return Column(
      children: [
        for (final row in [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: row
                .map(
                  (digit) => _KeyButton(
                    digit: digit,
                    onPressed: () => widget.onDigitPressed(digit),
                  ),
                )
                .toList(),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(width: 82),
            _KeyButton(digit: '0', onPressed: () => widget.onDigitPressed('0')),
            _KeyButton(
              icon: Icons.backspace_outlined,
              onPressed: widget.onBackspace,
            ),
          ],
        ),
      ],
    );
  }
}

class _KeyButton extends StatefulWidget {
  final String? digit;
  final IconData? icon;
  final VoidCallback onPressed;

  const _KeyButton({this.digit, this.icon, required this.onPressed});

  @override
  State<_KeyButton> createState() => _KeyButtonState();
}

class _KeyButtonState extends State<_KeyButton> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(7),
      child: Semantics(
        button: true,
        label: widget.digit ?? 'Backspace',
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: GestureDetector(
            onTapDown: (_) {
              setState(() => _pressed = true);
              HapticFeedback.selectionClick();
            },
            onTapUp: (_) {
              setState(() => _pressed = false);
              widget.onPressed();
            },
            onTapCancel: () => setState(() => _pressed = false),
            child: AnimatedContainer(
              duration: AppMotion.orZero(AppMotion.fast),
              curve: AppMotion.easeOutStrong,
              width: 62,
              height: 62,
              transform: Matrix4.identity()
                ..scaleByDouble(
                  _pressed ? 0.9 : (_hovered ? 1.07 : 1.0),
                  _pressed ? 0.9 : (_hovered ? 1.07 : 1.0),
                  _pressed ? 0.9 : (_hovered ? 1.07 : 1.0),
                  1.0,
                ),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: _pressed
                      ? [
                          AppColors.auroraGold.withValues(alpha: 0.55),
                          AppColors.deepRose.withValues(alpha: 0.45),
                        ]
                      : [
                          AppColors.moonlight.withValues(
                            alpha: _hovered ? 0.20 : 0.12,
                          ),
                          AppColors.inkDeep.withValues(alpha: 0.35),
                        ],
                ),
                border: Border.all(
                  color: _pressed
                      ? AppColors.auroraGold
                      : AppColors.moonlight.withValues(
                          alpha: _hovered ? 0.55 : 0.24,
                        ),
                  width: 1.4,
                ),
                boxShadow: [
                  if (_hovered || _pressed)
                    BoxShadow(
                      color: AppColors.auroraGold.withValues(
                        alpha: _pressed ? 0.5 : 0.28,
                      ),
                      blurRadius: 18,
                      spreadRadius: -2,
                    ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Center(
                child: widget.digit != null
                    ? Text(
                        widget.digit!,
                        style: AppTypography.outfitWhite.copyWith(
                          fontSize: 24,
                          fontWeight: FontWeight.w500,
                          color: _pressed
                              ? AppColors.inkDeep
                              : AppColors.petalWhite,
                        ),
                      )
                    : Icon(
                        widget.icon,
                        color: _pressed
                            ? AppColors.inkDeep
                            : AppColors.blushGold,
                        size: 21,
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
