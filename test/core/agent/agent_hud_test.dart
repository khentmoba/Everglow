import 'package:everglow/core/agent/agent_hud.dart';
import 'package:everglow/core/agent/agent_mode.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('HUD above the Navigator collapses without a tooltip overlay', (
    tester,
  ) async {
    AgentMode.isActive.value = true;
    AgentMode.showHud.value = true;
    AgentMode.hudCollapsed.value = false;
    addTearDown(() {
      AgentMode.isActive.value = false;
      AgentMode.hudCollapsed.value = false;
    });
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: const Scaffold(),
        builder: (context, child) => AgentHudOverlay(child: child!),
      ),
    );
    await tester.tap(
      find.bySemanticsLabel('Collapse HUD (clean screenshot mode)'),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    semantics.dispose();
    expect(AgentMode.hudCollapsed.value, isTrue);
    expect(find.text('AGENT SANDBOX'), findsNothing);
    await tester.tap(find.byIcon(Icons.bolt_rounded));
    await tester.pumpAndSettle();
    expect(find.text('AGENT SANDBOX'), findsOneWidget);
    await tester.tap(find.text('Screen edges'));
    await tester.pumpAndSettle();
    expect(
      find.text('Screen measurement is available on web.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Close measurement'));
    await tester.pumpAndSettle();
    expect(find.text('Screen measurement is available on web.'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
