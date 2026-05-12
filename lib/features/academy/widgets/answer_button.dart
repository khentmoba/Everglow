import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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

class _AnswerButtonState extends State<AnswerButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: ElevatedButton(
          onPressed: widget.isLocked || widget.onTap == null
              ? null
              : () {
                  _controller.forward().then((_) => _controller.reverse());
                  widget.onTap!();
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: widget.isLocked ? Colors.grey[100] : Colors.white,
            foregroundColor: const Color(0xFFFF69B4),
            minimumSize: const Size(double.infinity, 60),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            elevation: 2,
            shadowColor: Colors.pink.withOpacity(0.1),
          ),
          child: Text(
            widget.text,
            style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}
