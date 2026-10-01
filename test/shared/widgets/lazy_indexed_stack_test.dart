import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:everglow/shared/widgets/everglow/lazy_indexed_stack.dart';

class _Tab extends StatefulWidget {
  const _Tab(this.index, this.mounts);
  final int index;
  final List<int> mounts;
  @override
  State<_Tab> createState() => _TabState();
}

class _TabState extends State<_Tab> {
  @override
  void initState() {
    super.initState();
    widget.mounts.add(widget.index);
  }

  @override
  Widget build(BuildContext context) =>
      Text('${widget.index}:${TickerMode.valuesOf(context).enabled}');
}

void main() {
  testWidgets('only visited tabs mount and their state survives switches', (
    tester,
  ) async {
    final mounts = <int>[];
    Widget build(int index, {bool active = true}) => MaterialApp(
      home: LazyIndexedStack(
        index: index,
        active: active,
        children: List.generate(8, (i) => _Tab(i, mounts)),
      ),
    );
    await tester.pumpWidget(build(0));
    expect(mounts, [0]);
    expect(find.text('0:true'), findsOneWidget);
    await tester.pumpWidget(build(2));
    expect(mounts, [0, 2]);
    expect(find.text('0:false', skipOffstage: false), findsOneWidget);
    expect(find.text('2:true'), findsOneWidget);
    await tester.pumpWidget(build(0));
    expect(mounts, [0, 2]);
    await tester.pumpWidget(build(0, active: false));
    expect(find.text('0:false', skipOffstage: false), findsOneWidget);
    await tester.pumpWidget(build(3, active: false));
    expect(mounts, [
      0,
      2,
    ], reason: 'An overlay must not mount another hidden tab');
    await tester.pumpWidget(build(3));
    expect(mounts, [0, 2, 3]);
  });
}
