import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:everglow/core/theme/app_colors.dart';
import 'package:everglow/features/trip_kit/presentation/widgets/trip_ui.dart';

// Clair reads trips on her phone: long item labels, peso amounts, and the
// two-field expense row must never overflow at 360px or on tablet.
Widget _rows() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const TripSectionTitle(
        icon: Icons.backpack_rounded,
        title: 'PACKING',
        hue: AppColors.warmAmber,
        trailing: '12/48',
      ),
      TripCheckRow(
        label:
            'An extremely long packing label that must wrap instead of overflowing the card on narrow phones',
        subtitle:
            'packed by someone with a very long username for wrapping',
        checked: false,
        hue: AppColors.warmAmber,
        toggleLabel: 'Pack test item',
        onToggle: () {},
        onDelete: () {},
      ),
      TripCheckRow(
        label: 'Sunscreen',
        checked: true,
        hue: AppColors.warmAmber,
        toggleLabel: 'Pack sunscreen',
        onToggle: () {},
        onDelete: () {},
      ),
      TripAddRow(
        controller: TextEditingController(),
        hint: 'What (e.g. Gas)',
        hue: AppColors.auroraTeal,
        secondController: TextEditingController(),
        secondHint: '₱ amount',
        secondKeyboardType: TextInputType.number,
        onAdd: () {},
      ),
    ],
  );
}

Future<void> _pump(WidgetTester tester, Size size) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [_rows()],
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
  expect(tester.takeException(), isNull);
}

void main() {
  testWidgets('Trip rows have no phone overflow at 360px', (tester) async {
    await _pump(tester, const Size(360, 800));
    final row = tester.getRect(find.byType(TripAddRow).first);
    expect(row.right, lessThanOrEqualTo(360.1));
  });

  testWidgets('Trip rows have no tablet overflow at 810px', (tester) async {
    await _pump(tester, const Size(810, 1080));
    final row = tester.getRect(find.byType(TripAddRow).first);
    expect(row.right, lessThanOrEqualTo(810.1));
  });
}
