import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_colors.dart';
import '../state/gateway_state.dart';

/// Elegant glass passcode keypad with gold accents and a shake-on-error.
///
/// Private-entry copy stays minimal on purpose: two quiet lines explain
/// what this is without turning the door into a landing page. No signup,
/// no links, no marketing.
class PasscodeInput extends StatefulWidget {
  final String input;
  final Function(String) onDigitPressed;
  final VoidCallback onBackspace;
  final bool isError;
  final bool isVerifying;
  final GatewayFailureReason? failureReason;

  const PasscodeInput({
    super.key,
    required this.input,
    required this.onDigitPressed,
    required this.onBackspace,
    this.isError = false,
    this.isVerifying = false,
    this.failureReason,
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
      duration: AppMotion.orZero(const Duration(milliseconds: 520)),
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
      // Reduced motion: skip the visual shake, keep the haptic nudge so
      // the failure is still perceivable without animation.
      if (!AppMotion.reduced) {
        _shakeController.forward(from: 0);
      }
      HapticFeedback.vibrate();
    }
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _handlePadKey(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    if (widget.isVerifying) return;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.backspace ||
        key == LogicalKeyboardKey.delete) {
      widget.onBackspace();
      return;
    }
    final label = key.keyLabel;
    if (label.length == 1 && RegExp(r'^[0-9]$').hasMatch(label)) {
      widget.onDigitPressed(label);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Focus(
        autofocus: true,
        onKeyEvent: (node, event) {
          final before = widget.input;
          _handlePadKey(event);
          // Only claim the event when it actually typed or deleted.
          if (event is! KeyDownEvent) return KeyEventResult.ignored;
          final key = event.logicalKey;
          final isDigit = key.keyLabel.length == 1 &&
              RegExp(r'^[0-9]$').hasMatch(key.keyLabel);
          final isDelete = key == LogicalKeyboardKey.backspace ||
              key == LogicalKeyboardKey.delete;
          if ((isDigit || isDelete) && !widget.isVerifying) {
            // If input didn't change (e.g. 5th digit while full), let it
            // pass through instead of swallowing the keystroke.
            if (isDelete && before.isEmpty) {
              return KeyEventResult.ignored;
            }
            if (isDigit && before.length >= 4) {
              return KeyEventResult.ignored;
            }
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: Semantics(
          container: true,
          label: 'Passcode entry for Khent and Clair',
          hint: 'Enter your 4-digit passcode',
          child: AnimatedBuilder(
            animation: _shakeAnimation,
            builder: (context, _) {
              final wave = AppMotion.reduced
                  ? 0.0
                  : math.sin(_shakeAnimation.value / 13 * math.pi);
              return Transform.translate(
                offset: Offset(wave * _shakeAnimation.value, 0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 10),
                    _buildDots(),
                    const SizedBox(height: 8),
                    _buildStatusLine(),
                    const SizedBox(height: 10),
                    _buildNumPad(),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Your private place for Khent & Clair',
          textAlign: TextAlign.center,
          style: AppTypography.bodySmall().copyWith(
            color: AppColors.roseQuartz.withValues(alpha: 0.88),
            fontSize: 13,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Enter your 4-digit passcode',
          textAlign: TextAlign.center,
          style: AppTypography.bodySmall().copyWith(
            color: AppColors.textMuted.withValues(alpha: 0.85),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildDots() {
    final progressLabel = widget.isVerifying
        ? 'Verifying code'
        : '${widget.input.length} of 4 digits entered';
    return Semantics(
      label: 'Passcode progress',
      value: progressLabel,
      liveRegion: true,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(4, (index) {
          final isFilled = index < widget.input.length;
          return AnimatedContainer(
            duration: AppMotion.orZero(const Duration(milliseconds: 220)),
            curve: AppMotion.easeOutStrong,
            margin: const EdgeInsets.symmetric(horizontal: 10),
            // Keep width == height so BoxShape.circle stays a true circle.
            // Filled dots grow + glow yellow, deleted dots shrink back.
            width: isFilled ? 18 : 14,
            height: isFilled ? 18 : 14,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.isError
                  ? AppColors.error.withValues(alpha: 0.70)
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
                        blurRadius: 12,
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
      ),
    );
  }

  Widget _buildStatusLine() {
    // Fixed height so swapping between progress / verifying / error never
    // shifts the keypad underneath.
    return SizedBox(
      height: 30,
      child: Center(
        child: AnimatedSwitcher(
          duration: AppMotion.orZero(const Duration(milliseconds: 220)),
          child: _statusChild(),
        ),
      ),
    );
  }

  Widget _statusChild() {
    if (widget.isVerifying) {
      return Row(
        key: const ValueKey('verifying'),
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 13,
            height: 13,
            child: AppMotion.reduced
                ? const Icon(
                    Icons.lock_outline,
                    size: 13,
                    color: AppColors.auroraGold,
                    semanticLabel: 'Verifying',
                  )
                : const CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.auroraGold,
                  ),
          ),
          const SizedBox(width: 8),
          Text(
            'Opening your space…',
            style: AppTypography.bodySmall().copyWith(
              color: AppColors.blushGold.withValues(alpha: 0.92),
              fontSize: 12,
            ),
          ),
        ],
      );
    }
    if (widget.isError || widget.failureReason != null) {
      final message =
          widget.failureReason == GatewayFailureReason.connection
              ? 'Everglow couldn’t connect. Check your connection and try again.'
              : 'That code didn’t open Everglow. Try again.';
      return Padding(
        key: ValueKey('error-$message'),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Text(
          message,
          key: ValueKey(message),
          textAlign: TextAlign.center,
          maxLines: 2,
          style: AppTypography.bodySmall().copyWith(
            color: AppColors.textMuted,
            fontSize: 12,
            height: 1.25,
          ),
        ),
      );
    }
    return Text(
      '${widget.input.length} of 4',
      key: ValueKey('progress-${widget.input.length}'),
      style: AppTypography.bodySmall().copyWith(
        color: AppColors.textMuted.withValues(alpha: 0.62),
        fontSize: 11,
        letterSpacing: 0.4,
      ),
    );
  }

  Widget _buildNumPad() {
    return IgnorePointer(
      ignoring: widget.isVerifying,
      child: AnimatedOpacity(
        duration: AppMotion.orZero(const Duration(milliseconds: 200)),
        opacity: widget.isVerifying ? 0.55 : 1.0,
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
                const SizedBox(width: 68),
                _KeyButton(
                    digit: '0', onPressed: () => widget.onDigitPressed('0')),
                _KeyButton(
                  icon: Icons.backspace_outlined,
                  onPressed: widget.onBackspace,
                ),
              ],
            ),
          ],
        ),
      ),
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
  bool _focused = false;
  late final FocusNode _focusNode;

  String get _label => widget.digit ?? 'Backspace';

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(debugLabel: 'passcode-key-$_label');
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showFocusRing = _focused;
    return Padding(
      padding: const EdgeInsets.all(6),
      child: Semantics(
        button: true,
        label: widget.digit != null ? 'Digit ${widget.digit}' : 'Backspace',
        hint: widget.digit != null
            ? 'Enters ${widget.digit}'
            : 'Deletes the last digit',
        child: Focus(
          focusNode: _focusNode,
          onFocusChange: (value) => setState(() => _focused = value),
          onKeyEvent: (node, event) {
            if (event is KeyDownEvent &&
                (event.logicalKey == LogicalKeyboardKey.enter ||
                    event.logicalKey == LogicalKeyboardKey.numpadEnter ||
                    event.logicalKey == LogicalKeyboardKey.space)) {
              widget.onPressed();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
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
                // Move keyboard focus here too so Tab order stays where
                // Clair tapped and Enter repeats the same key.
                if (!_focusNode.hasFocus) _focusNode.requestFocus();
                widget.onPressed();
              },
              onTapCancel: () => setState(() => _pressed = false),
              child: AnimatedContainer(
                duration: AppMotion.orZero(AppMotion.fast),
                curve: AppMotion.easeOutStrong,
                width: 56,
                height: 56,
                transform: Matrix4.identity()
                  ..scaleByDouble(
                    _pressed ? 0.9 : (_hovered ? 1.04 : 1.0),
                    _pressed ? 0.9 : (_hovered ? 1.04 : 1.0),
                    _pressed ? 0.9 : (_hovered ? 1.04 : 1.0),
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
                    color: showFocusRing
                        ? AppColors.auroraGold
                        : (_pressed
                            ? AppColors.auroraGold
                            : AppColors.moonlight.withValues(
                                alpha: _hovered ? 0.55 : 0.24,
                              )),
                    width: showFocusRing ? 2.4 : 1.4,
                  ),
                  boxShadow: [
                    if (showFocusRing)
                      BoxShadow(
                        color:
                            AppColors.auroraGold.withValues(alpha: 0.55),
                        blurRadius: 16,
                        spreadRadius: 1,
                      )
                    else if (_hovered || _pressed)
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
                          semanticLabel: 'Backspace',
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
