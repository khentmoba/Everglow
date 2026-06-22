import 'package:flutter/material.dart';
import 'package:everglow/core/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';

class DropStarDialog extends StatefulWidget {
  const DropStarDialog({super.key});

  @override
  State<DropStarDialog> createState() => _DropStarDialogState();
}

class _DropStarDialogState extends State<DropStarDialog> {
  final TextEditingController _controller = TextEditingController();
  bool _isSubmitEnabled = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_validateInput);
  }

  void _validateInput() {
    setState(() {
      _isSubmitEnabled = _controller.text.trim().isNotEmpty;
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_validateInput);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 32),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.velvet,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppTheme.blushGold.withValues(alpha: 0.25), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: AppTheme.deepRose.withValues(alpha: 0.3),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Drop a Star ✨",
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.roseQuartz,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _controller,
                maxLines: 3,
                style: GoogleFonts.outfit(color: AppTheme.petalWhite),
                decoration: InputDecoration(
                  hintText: "What are you grateful for today?",
                  hintStyle: GoogleFonts.outfit(color: AppTheme.petalWhite.withValues(alpha: 0.4)),
                  filled: true,
                  fillColor: AppTheme.twilight,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: AppTheme.blushGold.withValues(alpha: 0.2)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: AppTheme.blushGold),
                  ),
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      "Cancel",
                      style: GoogleFonts.outfit(color: AppTheme.roseQuartz.withValues(alpha: 0.6)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isSubmitEnabled
                        ? () => Navigator.pop(context, _controller.text)
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.deepRose,
                      foregroundColor: AppTheme.petalWhite,
                      disabledBackgroundColor: AppTheme.deepRose.withValues(alpha: 0.3),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: Text("Drop it!", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
