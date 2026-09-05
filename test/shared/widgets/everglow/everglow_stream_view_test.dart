import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:everglow/shared/widgets/everglow/everglow_error_state.dart';
import 'package:everglow/shared/widgets/everglow/everglow_skeleton.dart';
import 'package:everglow/shared/widgets/everglow/everglow_stream_view.dart';

Widget _wrap(Widget child) =>
    MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('shows loading then data', (tester) async {
    final controller = StreamController<List<String>>();
    addTearDown(controller.close);

    await tester.pumpWidget(
      _wrap(
        EverglowStreamView<List<String>>(
          stream: controller.stream,
          builder: (context, items) =>
              ListView(children: [for (final i in items) Text(i)]),
        ),
      ),
    );

    expect(find.byType(EverglowLoadingState), findsOneWidget);

    controller.add(['a', 'b']);
    await tester.pump();

    expect(find.text('a'), findsOneWidget);
    expect(find.text('b'), findsOneWidget);
  });

  testWidgets('shows empty view when isEmpty matches', (tester) async {
    final controller = StreamController<List<String>>();
    addTearDown(controller.close);

    await tester.pumpWidget(
      _wrap(
        EverglowStreamView<List<String>>(
          stream: controller.stream,
          isEmpty: (items) => items.isEmpty,
          emptyView: const Text('nothing here'),
          builder: (context, items) => Text('${items.length} items'),
        ),
      ),
    );

    controller.add([]);
    await tester.pump();

    expect(find.text('nothing here'), findsOneWidget);
    expect(find.text('0 items'), findsNothing);
  });

  testWidgets('shows error card on stream error', (tester) async {
    final controller = StreamController<List<String>>();
    addTearDown(controller.close);

    await tester.pumpWidget(
      _wrap(
        EverglowStreamView<List<String>>(
          stream: controller.stream,
          errorMessage: 'Could not load things',
          builder: (context, items) => Text('${items.length} items'),
        ),
      ),
    );

    controller.addError(Exception('boom'));
    await tester.pump();

    expect(find.byType(EverglowErrorState), findsOneWidget);
    expect(find.textContaining('Could not load things'), findsOneWidget);
  });
}
