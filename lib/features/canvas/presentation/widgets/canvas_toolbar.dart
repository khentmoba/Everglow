import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:everglow/core/theme/app_theme.dart';

enum CanvasTool { pen, eraser, text }

class CanvasToolbar extends StatelessWidget {
  final CanvasTool activeTool;
  final String activeColor;
  final double strokeWidth;
  final Function(CanvasTool) onToolChanged;
  final Function(String) onColorChanged;
  final Function(double) onStrokeWidthChanged;
  final VoidCallback onClear;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final bool canUndo;
  final bool canRedo;

  const CanvasToolbar({
    super.key,
    required this.activeTool,
    required this.activeColor,
    this.strokeWidth = 3.0,
    required this.onToolChanged,
    required this.onColorChanged,
    required this.onStrokeWidthChanged,
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
              color: AppTheme.velvet.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: AppTheme.moonlight.withValues(alpha: 0.18),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.deepRose.withValues(alpha: 0.15),
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
                    semanticLabel: 'Pen tool',
                  ),
                  _ToolButton(
                    icon: Icons.auto_fix_normal_rounded,
                    isActive: activeTool == CanvasTool.eraser,
                    onTap: () => onToolChanged(CanvasTool.eraser),
                    semanticLabel: 'Eraser tool',
                  ),
                  _ToolButton(
                    icon: Icons.text_fields_rounded,
                    isActive: activeTool == CanvasTool.text,
                    onTap: () => onToolChanged(CanvasTool.text),
                    semanticLabel: 'Text tool',
                  ),

                  const _VerticalDivider(),

                  // History
                  _ToolButton(
                    icon: Icons.undo_rounded,
                    isActive: false,
                    onTap: onUndo,
                    color: canUndo
                        ? AppTheme.roseQuartz
                        : AppTheme.petalWhite.withValues(alpha: 0.2),
                    semanticLabel: 'Undo',
                  ),
                  _ToolButton(
                    icon: Icons.redo_rounded,
                    isActive: false,
                    onTap: onRedo,
                    color: canRedo
                        ? AppTheme.roseQuartz
                        : AppTheme.petalWhite.withValues(alpha: 0.2),
                    semanticLabel: 'Redo',
                  ),

                  const _VerticalDivider(),

                  // Color Palette - Scrollable for mobile
                  ...palette.map(
                    (hex) => _ColorButton(
                      hex: hex,
                      isActive:
                          activeColor == hex && activeTool == CanvasTool.pen,
                      onTap: () {
                        onToolChanged(CanvasTool.pen);
                        onColorChanged(hex);
                      },
                    ),
                  ),

                  const _VerticalDivider(),

                  // Stroke Width Slider
                  Semantics(
                    label: 'Stroke width: ${strokeWidth.round()}',
                    child: SizedBox(
                      width: 80,
                      // Slider fills its bounded max height in newer Flutter
                      // versions; pin the height so the toolbar stays compact.
                      height: 48,
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 3,
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 6,
                          ),
                          activeTrackColor: AppTheme.roseQuartz,
                          inactiveTrackColor: AppTheme.moonlight.withValues(
                            alpha: 0.15,
                          ),
                          thumbColor: AppTheme.blushGold,
                          overlayColor: AppTheme.blushGold.withValues(
                            alpha: 0.1,
                          ),
                        ),
                        child: Slider(
                          value: strokeWidth,
                          min: 1.0,
                          max: 12.0,
                          onChanged: onStrokeWidthChanged,
                        ),
                      ),
                    ),
                  ),

                  const _VerticalDivider(),

                  // Clear Button
                  _ToolButton(
                    icon: Icons.delete_outline_rounded,
                    isActive: false,
                    onTap: onClear,
                    color: Colors.redAccent.withValues(alpha: 0.8),
                    semanticLabel: 'Clear canvas',
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
      color: AppTheme.moonlight.withValues(alpha: 0.1),
    );
  }
}

class _ToolButton extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;
  final Color? color;
  final String? semanticLabel;

  const _ToolButton({
    required this.icon,
    required this.isActive,
    required this.onTap,
    this.color,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      button: true,
      enabled: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(10),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: isActive
                ? AppTheme.deepRose.withValues(alpha: 0.2)
                : Colors.transparent,
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: isActive
                ? AppTheme.roseQuartz
                : (color ?? AppTheme.petalWhite.withValues(alpha: 0.6)),
            size: 24,
          ),
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

  String _colorName(String hex) {
    switch (hex) {
      case '#FFC0CB':
        return 'Pink';
      case '#B0E0E6':
        return 'Powder Blue';
      case '#FFFACD':
        return 'Lemon Chiffon';
      case '#98FB98':
        return 'Pale Green';
      case '#E6E6FA':
        return 'Lavender';
      default:
        return 'Color';
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = Color(int.parse(hex.replaceFirst('#', 'FF'), radix: 16));

    return Semantics(
      label: '${_colorName(hex)} color',
      button: true,
      child: GestureDetector(
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
              color: isActive ? AppTheme.roseQuartz : Colors.transparent,
              width: isActive ? 2.5 : 2,
            ),
            boxShadow: [
              if (isActive)
                BoxShadow(
                  color: color.withValues(alpha: 0.6),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
