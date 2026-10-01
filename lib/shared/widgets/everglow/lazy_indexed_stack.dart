import 'package:flutter/material.dart';

/// Mount tabs on first visit, preserving their scroll/data on later switches.
/// Hidden tabs disable tickers; media widgets must also respect TickerMode.
class LazyIndexedStack extends StatefulWidget {
  const LazyIndexedStack({
    super.key,
    required this.index,
    required this.children,
    this.active = true,
  });

  final int index;
  final List<Widget> children;
  final bool active;

  @override
  State<LazyIndexedStack> createState() => _LazyIndexedStackState();
}

class _LazyIndexedStackState extends State<LazyIndexedStack> {
  final Set<int> _visited = {};

  @override
  Widget build(BuildContext context) {
    if (widget.active) _visited.add(widget.index);
    return IndexedStack(
      index: widget.index,
      children: [
        for (var i = 0; i < widget.children.length; i++)
          TickerMode(
            enabled: widget.active && i == widget.index,
            child: _visited.contains(i)
                ? widget.children[i]
                : const SizedBox.shrink(),
          ),
      ],
    );
  }
}
