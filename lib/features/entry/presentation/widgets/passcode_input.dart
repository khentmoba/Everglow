import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_typography.dart';
import '../state/gateway_state.dart';

/// Private passphrase field for Khent and Clair. It deliberately replaces the
/// old four-digit keypad: weak gateway secrets are no longer accepted.
class PasscodeInput extends StatefulWidget {
  final String input;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmit;
  final bool canSubmit;
  final bool isError;
  final bool isVerifying;
  final GatewayFailureReason? failureReason;

  const PasscodeInput({
    super.key,
    required this.input,
    required this.onChanged,
    required this.onSubmit,
    required this.canSubmit,
    this.isError = false,
    this.isVerifying = false,
    this.failureReason,
  });

  @override
  State<PasscodeInput> createState() => _PasscodeInputState();
}

class _PasscodeInputState extends State<PasscodeInput>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _controller;
  bool _obscured = true;
  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.input);
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
    if (widget.input != _controller.text) {
      _controller.value = TextEditingValue(
        text: widget.input,
        selection: TextSelection.collapsed(offset: widget.input.length),
      );
    }
    if (widget.isError && !oldWidget.isError) {
      if (!AppMotion.reduced) _shakeController.forward(from: 0);
      HapticFeedback.vibrate();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!widget.isVerifying && widget.canSubmit) widget.onSubmit();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Passphrase entry for Khent and Clair',
      hint: 'Enter your private passphrase',
      child: AnimatedBuilder(
        animation: _shakeAnimation,
        builder: (context, _) {
          final wave = AppMotion.reduced
              ? 0.0
              : math.sin(_shakeAnimation.value / 13 * math.pi);
          return Transform.translate(
            offset: Offset(wave * _shakeAnimation.value, 0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildField(),
                  const SizedBox(height: 10),
                  _buildStatusLine(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildField() {
    return TextField(
      controller: _controller,
      autofocus: true,
      enabled: !widget.isVerifying,
      obscureText: _obscured,
      autocorrect: false,
      enableSuggestions: false,
      maxLength: 256,
      textInputAction: TextInputAction.done,
      onChanged: widget.onChanged,
      onSubmitted: (_) => _submit(),
      style: AppTypography.outfitWhite.copyWith(
        color: AppColors.petalWhite,
        fontSize: 16,
        letterSpacing: 1.1,
      ),
      decoration: InputDecoration(
        hintText: 'Private passphrase',
        hintStyle: AppTypography.outfitWhite.copyWith(
          color: AppColors.petalWhite.withValues(alpha: 0.48),
        ),
        counterText: '',
        prefixIcon: const Icon(
          Icons.lock_outline_rounded,
          color: AppColors.blushGold,
        ),
        suffixIcon: IconButton(
          tooltip: _obscured ? 'Show passphrase' : 'Hide passphrase',
          icon: Icon(
            _obscured
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
          ),
          color: AppColors.blushGold,
          onPressed: () => setState(() => _obscured = !_obscured),
        ),
        filled: true,
        fillColor: AppColors.twilight.withValues(alpha: 0.88),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: widget.isError
                ? AppColors.error
                : AppColors.blushGold.withValues(alpha: 0.32),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.blushGold),
        ),
      ),
    );
  }

  Widget _buildStatusLine() {
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
            'Opening your space...',
            style: AppTypography.bodySmall().copyWith(
              color: AppColors.blushGold.withValues(alpha: 0.92),
              fontSize: 12,
            ),
          ),
        ],
      );
    }
    if (widget.isError || widget.failureReason != null) {
      final message = widget.failureReason == GatewayFailureReason.connection
          ? 'Everglow could not connect. Check your connection and try again.'
          : 'That passphrase did not open Everglow. Try again.';
      return Text(
        message,
        key: ValueKey(message),
        textAlign: TextAlign.center,
        maxLines: 2,
        style: AppTypography.bodySmall().copyWith(
          color: AppColors.textMuted,
          fontSize: 12,
          height: 1.25,
        ),
      );
    }

    return Row(
      key: ValueKey('progress-${widget.input.length}'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${widget.input.length} / 16+ characters',
          style: AppTypography.bodySmall().copyWith(
            color: AppColors.textMuted.withValues(alpha: 0.72),
            fontSize: 11,
          ),
        ),
        const SizedBox(width: 10),
        IconButton.filled(
          tooltip: 'Unlock Everglow',
          onPressed: widget.canSubmit ? _submit : null,
          style: IconButton.styleFrom(
            backgroundColor: AppColors.deepRose,
            disabledBackgroundColor: AppColors.deepRose.withValues(alpha: 0.3),
            fixedSize: const Size(34, 34),
            padding: EdgeInsets.zero,
          ),
          icon: widget.isVerifying
              ? const SizedBox.shrink()
              : const Icon(Icons.arrow_forward_rounded, size: 18),
        ),
      ],
    );
  }
}
