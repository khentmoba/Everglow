import 'package:flutter/material.dart';

/// Horizontal scroll row with fade-right affordance.
class EverglowFadeRow extends StatelessWidget {
  final Widget child;
  final double fadeStop;
  final EdgeInsets? padding;
  const EverglowFadeRow({super.key, required this.child, this.fadeStop = 0.85, this.padding});
  @override
  Widget build(BuildContext context) {
    final scroll = SingleChildScrollView(scrollDirection: Axis.horizontal, child: child);
    final masked = ShaderMask(
      shaderCallback: (rect) => LinearGradient(begin: Alignment.centerLeft, end: Alignment.centerRight, colors: const [Colors.white, Colors.white, Colors.transparent], stops: [0.0, fadeStop, 1.0]).createShader(rect),
      blendMode: BlendMode.dstIn,
      child: scroll,
    );
    if (padding != null) return Padding(padding: padding!, child: masked);
    return masked;
  }
}
class EverglowChipFadeRow extends StatelessWidget {
  final List<Widget> children;
  final double spacing;
  final double fadeStop;
  final EdgeInsets? padding;
  const EverglowChipFadeRow({super.key, required this.children, this.spacing = 8, this.fadeStop = 0.85, this.padding});
  @override
  Widget build(BuildContext context) {
    return EverglowFadeRow(fadeStop: fadeStop, padding: padding, child: Row(children: [for (int i=0;i<children.length;i++) ...[children[i], if (i!=children.length-1) SizedBox(width: spacing)]]));
  }
}
