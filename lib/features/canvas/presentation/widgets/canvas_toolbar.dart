import 'dart:ui';
import 'package:flutter/material.dart';

enum CanvasTool { pen, eraser }

class CanvasToolbar extends StatelessWidget {
  final CanvasTool activeTool;
  final String activeColor;
  final Function(CanvasTool) onToolChanged;
  final Function(String) onColorChanged;
  final VoidCallback onClear;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final bool canUndo;
  final bool canRedo;

  const CanvasToolbar({
    super.key,
    required this.activeTool,
    required this.activeColor,
    required this.onToolChanged,
    required this.onColorChanged,
    required this.onClear,
    required this.onUndo,
    required this.onRedo,
    required this.canUndo,
    required this.canRedo,
  });

  static const List<String> palette = [
    '#FFC0CB', // Pink
    '#B0E0E6', // Powder Blue
    '#FFFACD', // Lemon Chiffon (Yellow)
    '#98FB98', // Pale Green
    '#E6E6FA', // Lavender
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.6),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: Colors.white.withOpacity(0.5), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.pink.withOpacity(0.05),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Tool Selection
                  _ToolButton(
                    icon: Icons.edit_rounded,
                    isActive: activeTool == CanvasTool.pen,
                    onTap: () => onToolChanged(CanvasTool.pen),
                  ),
                  _ToolButton(
                    icon: Icons.auto_fix_normal_rounded,
                    isActive: activeTool == CanvasTool.eraser,
                    onTap: () => onToolChanged(CanvasTool.eraser),
                  ),
                  
                  const _VerticalDivider(),

                  // History
                  _ToolButton(
                    icon: Icons.undo_rounded,
                    isActive: false,
                    onTap: onUndo,
                    color: canUndo ? Colors.pink[400] : Colors.grey[300],
                  ),
                  _ToolButton(
                    icon: Icons.redo_rounded,
                    isActive: false,
                    onTap: onRedo,
                    color: canRedo ? Colors.pink[400] : Colors.grey[300],
                  ),

                  const _VerticalDivider(),

                  // Color Palette - Scrollable for mobile
                  ...palette.map((hex) => _ColorButton(
                    hex: hex,
                    isActive: activeColor == hex && activeTool == CanvasTool.pen,
                    onTap: () {
                      onToolChanged(CanvasTool.pen);
                      onColorChanged(hex);
                    },
                  )),

                  const _VerticalDivider(),

                  // Clear Button
                  _ToolButton(
                    icon: Icons.delete_outline_rounded,
                    isActive: false,
                    onTap: onClear,
                    color: Colors.redAccent.withOpacity(0.6),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  const _VerticalDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 24,
      width: 1,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: Colors.pink.withOpacity(0.1),
    );
  }
}

class _ToolButton extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;
  final Color? color;

  const _ToolButton({
    required this.icon,
    required this.isActive,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(10),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: isActive ? Colors.pink.withOpacity(0.2) : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: isActive ? Colors.pink : (color ?? Colors.pink[300]),
          size: 24,
        ),
      ),
    );
  }
}

class _ColorButton extends StatelessWidget {
  final String hex;
  final bool isActive;
  final VoidCallback onTap;

  const _ColorButton({
    required this.hex,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = Color(int.parse(hex.replaceFirst('#', 'FF'), radix: 16));
    
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 28,
        height: 28,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isActive ? Colors.pink : Colors.white,
            width: isActive ? 2.5 : 2,
          ),
          boxShadow: [
            if (isActive)
              BoxShadow(
                color: color.withOpacity(0.4),
                blurRadius: 8,
                spreadRadius: 1,
              ),
          ],
        ),
      ),
    );
  }
}
