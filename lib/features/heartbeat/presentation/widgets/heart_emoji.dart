import 'package:flutter/material.dart';

class HeartEmoji extends StatefulWidget {
  final String emoji;
  final bool isSelected;
  final VoidCallback onTap;
  final Color glowColor;

  const HeartEmoji({
    super.key,
    required this.emoji,
    required this.isSelected,
    required this.onTap,
    required this.glowColor,
  });

  @override
  State<HeartEmoji> createState() => _HeartEmojiState();
}

class _HeartEmojiState extends State<HeartEmoji>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.3,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));

    if (widget.isSelected) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(HeartEmoji oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSelected && !oldWidget.isSelected) {
      _controller.forward();
    } else if (!widget.isSelected && oldWidget.isSelected) {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: Semantics(
            button: true,
            label:
                'Mood ${widget.emoji}${widget.isSelected ? ", selected" : ""}',
            child: InkWell(
              onTap: widget.onTap,
              splashColor: widget.glowColor.withValues(alpha: 0.18),
              highlightColor: widget.glowColor.withValues(alpha: 0.06),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: widget.isSelected
                      ? [
                          BoxShadow(
                            color: widget.glowColor.withValues(alpha: 0.5),
                            blurRadius: 15,
                            spreadRadius: 5,
                          ),
                        ]
                      : [],
                ),
                child: Text(widget.emoji, style: const TextStyle(fontSize: 32)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
