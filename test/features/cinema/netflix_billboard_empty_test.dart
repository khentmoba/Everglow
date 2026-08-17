import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:everglow/features/cinema/data/models/media_item.dart';
import 'package:everglow/features/cinema/presentation/widgets/netflix/netflix_billboard.dart';

void main() {
  testWidgets('renders an empty billboard without throwing', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NetflixBillboard(
            items: const <MediaItem>[],
            onPlay: (_) {},
            onInfo: (_) {},
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });
}
