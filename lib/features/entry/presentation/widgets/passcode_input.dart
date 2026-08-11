import 'package:flutter/material.dart';
import 'package:everglow/shared/widgets/glass_container.dart';
import 'package:everglow/shared/widgets/bouncy_button.dart';
import 'package:everglow/core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';

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

class _PasscodeInputState extends State<PasscodeInput> with SingleTickerProviderStateMixin {
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 15).chain(CurveTween(curve: Curves.elasticIn)).animate(_shakeController)
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
      _shakeController.forward();
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
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_shakeAnimation.value, 0),
          child: Column(
            children: [
              _buildDots(),
              const SizedBox(height: 50),
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
        bool isFilled = index < widget.input.length;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 12),
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.isError
                ? Colors.redAccent
                : (isFilled ? AppTheme.blushGold : Colors.white10),
            boxShadow: isFilled ? [
              BoxShadow(
                color: AppTheme.blushGold.withValues(alpha: 0.6),
                blurRadius: 15,
                spreadRadius: 2,
              )
            ] : [],
            border: Border.all(
              color: isFilled ? AppTheme.blushGold : Colors.white24,
              width: 2,
            ),
          ),
        );
      }),
    );
  }

  Widget _buildNumPad() {
    return Column(
      children: [
        for (var row in [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: row.map((digit) => _NumButton(
              digit: digit,
              onPressed: () => widget.onDigitPressed(digit),
            )).toList(),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(width: 76),
            _NumButton(
              digit: '0',
              onPressed: () => widget.onDigitPressed('0'),
            ),
            _NumButton(
              icon: Icons.backspace_rounded,
              onPressed: widget.onBackspace,
            ),
          ],
        ),
      ],
    );
  }
}

class _NumButton extends StatelessWidget {
  final String? digit;
  final IconData? icon;
  final VoidCallback onPressed;

  const _NumButton({this.digit, this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: BouncyButton(
        onTap: onPressed,
        child: GlassContainer(
          width: 60,
          height: 60,
          borderRadius: BorderRadius.circular(30),
          opacity: 0.1,
          border: Border.all(color: Colors.white12, width: 1),
          child: Center(
            child: digit != null
                ? Text(
                    digit!,
                    style: AppTypography.outfitWhite.copyWith(
                      fontSize: 24,
                      fontWeight: FontWeight.w400,
                    ),
                  )
                : Icon(icon, color: AppTheme.deepRose, size: 20),
          ),
        ),
      ),
    );
  }
}
