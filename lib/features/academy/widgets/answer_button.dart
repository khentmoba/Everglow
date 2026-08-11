import 'package:flutter/material.dart';
import 'package:everglow/core/theme/app_colors.dart';
import 'package:everglow/core/theme/app_radius.dart';
import 'package:everglow/core/theme/app_typography.dart';

class AnswerButton extends StatefulWidget {
  final String text;
  final VoidCallback? onTap;
  final bool isLocked;

  const AnswerButton({
    super.key,
    required this.text,
    this.onTap,
    this.isLocked = false,
  });

  @override
  State<AnswerButton> createState() => _AnswerButtonState();
}

class _AnswerButtonState extends State<AnswerButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _hovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = !widget.isLocked && widget.onTap != null;
    return RepaintBoundary(
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: MouseRegion(
            cursor: enabled
                ? SystemMouseCursors.click
                : SystemMouseCursors.basic,
            onEnter: (_) => setState(() => _hovered = true),
            onExit: (_) => setState(() => _hovered = false),
            child: GestureDetector(
              onTap: enabled
                  ? () {
                      _controller.forward().then((_) => _controller.reverse());
                      widget.onTap!();
                    }
                  : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: double.infinity,
                height: 60,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: widget.isLocked
                        ? [
                            AppColors.moonlight.withValues(alpha: 0.06),
                            AppColors.inkDeep.withValues(alpha: 0.4),
                          ]
                        : _hovered
                        ? [
                            AppColors.deepRose.withValues(alpha: 0.28),
                            AppColors.velvet.withValues(alpha: 0.9),
                          ]
                        : [
                            AppColors.moonlight.withValues(alpha: 0.14),
                            AppColors.inkDeep.withValues(alpha: 0.6),
                          ],
                  ),
                  borderRadius: AppRadius.radiusXl,
                  border: Border.all(
                    color: widget.isLocked
                        ? AppColors.moonlight.withValues(alpha: 0.12)
                        : AppColors.auroraRose.withValues(
                            alpha: _hovered ? 0.7 : 0.35,
                          ),
                    width: 1.4,
                  ),
                  boxShadow: _hovered && !widget.isLocked
                      ? [
                          BoxShadow(
                            color: AppColors.deepRose.withValues(alpha: 0.3),
                            blurRadius: 18,
                            offset: const Offset(0, 6),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Text(
                    widget.text,
                    textAlign: TextAlign.center,
                    style: AppTypography.outfitWhite.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: widget.isLocked
                          ? AppColors.textDisabled
                          : AppColors.petalWhite,
                    ),
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
