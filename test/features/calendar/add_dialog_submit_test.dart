import 'package:everglow/features/calendar/presentation/widgets/add_event_dialog.dart';
import 'package:everglow/features/calendar/presentation/widgets/add_poll_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('event title rebuilds and enables Save', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: AddEventDialog(selectedDay: DateTime(2026, 9, 24))),
    );

    ElevatedButton saveButton() =>
        tester.widget(find.widgetWithText(ElevatedButton, 'Save'));
    expect(saveButton().onPressed, isNull);

    await tester.enterText(find.byType(TextField).first, 'Movie night');
    await tester.pump();

    expect(saveButton().onPressed, isNotNull);
  });

  test('poll submit guard requires title and two dates', () {
    expect(
      AddPollDialog.canCreate(title: '', dateCount: 2, saving: false),
      isFalse,
    );
    expect(
      AddPollDialog.canCreate(title: 'Dinner', dateCount: 1, saving: false),
      isFalse,
    );
    expect(
      AddPollDialog.canCreate(title: 'Dinner', dateCount: 2, saving: true),
      isFalse,
    );
    expect(
      AddPollDialog.canCreate(title: 'Dinner', dateCount: 2, saving: false),
      isTrue,
    );
  });

  testWidgets('poll title field rebuilds through onChanged', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AddPollDialog()));
    final field = find.byType(TextField).first;
    expect(tester.widget<TextField>(field).onChanged, isNotNull);

    await tester.enterText(field, 'Anniversary dinner');
    await tester.pump();
    expect(
      tester.widget<TextField>(field).controller?.text,
      'Anniversary dinner',
    );
  });
}
