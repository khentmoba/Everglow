import 'dart:async';

import 'package:everglow/core/services/auth_service.dart';
import 'package:everglow/features/trip_kit/data/models/trip.dart';
import 'package:everglow/features/trip_kit/data/services/trip_kit_service.dart';
import 'package:everglow/features/trip_kit/presentation/screens/trip_detail_screen.dart';
import 'package:everglow/features/trip_kit/presentation/screens/trip_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

class _FailingTripService implements TripKitService {
  @override
  Stream<List<Trip>> watchAll() => Stream.value(const []);

  var attempts = 0;

  @override
  Future<String> create(Trip trip) async {
    attempts++;
    throw StateError('offline');
  }

  @override
  Future<void> updateDetails(Trip trip) async => throw StateError('offline');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _DelayedTripService implements TripKitService {
  final trip = Trip(
    id: 'trip-1',
    title: 'Demo trip',
    createdBy: 'demo',
    createdAt: DateTime(2026, 1, 1),
  );
  final packSave = Completer<void>();
  final placeSave = Completer<void>();
  final expenseSave = Completer<void>();
  var packAttempts = 0;
  var placeAttempts = 0;
  var expenseAttempts = 0;

  @override
  Stream<Trip?> watchOne(String id) => Stream.value(trip);

  @override
  Future<void> addPackingItem(String tripId, TripPackItem item) {
    packAttempts++;
    return packSave.future;
  }

  @override
  Future<void> addPlace(String tripId, TripPlace place) {
    placeAttempts++;
    return placeSave.future;
  }

  @override
  Future<void> addExpense(String tripId, TripExpense expense) {
    expenseAttempts++;
    return expenseSave.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Auth extends ChangeNotifier implements AuthService {
  @override
  String? get currentUser => 'demo';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets(
    'failed trip creation keeps inputs and wraps retry error on phone',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final service = _FailingTripService();
      await tester.pumpWidget(
        ChangeNotifierProvider<AuthService>.value(
          value: _Auth(),
          child: MaterialApp.router(
            routerConfig: GoRouter(
              routes: [
                GoRoute(
                  path: '/',
                  builder: (_, _) => TripListScreen(service: service),
                ),
                GoRoute(
                  path: '/trips/:id',
                  builder: (_, _) => const SizedBox(),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('New trip'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(0), 'Demo getaway');
      await tester.enterText(find.byType(TextField).at(1), 'Batangas');
      await tester.tap(find.text('Create trip'));
      await tester.pumpAndSettle();

      expect(find.text('Create trip'), findsOneWidget);
      expect(find.text('Demo getaway'), findsOneWidget);
      expect(find.text('Batangas'), findsOneWidget);
      expect(
        find.textContaining('Your details are still here'),
        findsOneWidget,
      );
      expect(
        tester.getSize(find.byKey(const ValueKey('trip-save-error'))).height,
        greaterThan(18),
      );

      await tester.tap(find.text('Create trip'));
      await tester.pumpAndSettle();
      expect(service.attempts, 2);
      expect(find.text('Demo getaway'), findsOneWidget);
      expect(find.text('Batangas'), findsOneWidget);
    },
  );

  testWidgets('trip detail add forms ignore double taps during delayed saves', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final service = _DelayedTripService();
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) =>
                  TripDetailScreen(tripId: service.trip.id, service: service),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    Future<void> doubleTapAdd({
      required String buttonLabel,
      required String hint,
      required String value,
      required int Function() attempts,
      required Completer<void> save,
      String? secondHint,
      String? secondValue,
    }) async {
      final button = find.bySemanticsLabel(buttonLabel);
      final field = find.byWidgetPredicate(
        (widget) => widget is TextField && widget.decoration?.hintText == hint,
      );
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      await tester.enterText(field, value);
      if (secondHint != null && secondValue != null) {
        final secondField = find.byWidgetPredicate(
          (widget) =>
              widget is TextField && widget.decoration?.hintText == secondHint,
        );
        await tester.enterText(secondField, secondValue);
      }
      await tester.tap(button);
      await tester.pump();
      await tester.tap(button);
      await tester.pump();

      expect(attempts(), 1);
      expect(tester.widget<TextField>(field).controller!.text, value);
      save.complete();
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(field).controller!.text, isEmpty);
    }

    await doubleTapAdd(
      buttonLabel: 'Add Add to pack (e.g. Sunscreen)',
      hint: 'Add to pack (e.g. Sunscreen)',
      value: 'Sunscreen',
      attempts: () => service.packAttempts,
      save: service.packSave,
    );
    await doubleTapAdd(
      buttonLabel: 'Add Place',
      hint: 'Place',
      value: 'Cafe',
      attempts: () => service.placeAttempts,
      save: service.placeSave,
    );
    await doubleTapAdd(
      buttonLabel: 'Add What (e.g. Gas)',
      hint: 'What (e.g. Gas)',
      value: 'Taxi',
      attempts: () => service.expenseAttempts,
      save: service.expenseSave,
      secondHint: '₱',
      secondValue: '120',
    );
  });

  testWidgets('failed trip edit keeps entered details in the sheet', (
    tester,
  ) async {
    final service = _FailingTripService();
    final trip = Trip(
      id: 'trip-1',
      title: 'Saved trip',
      createdBy: 'demo',
      createdAt: DateTime(2026, 1, 1),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () =>
                  showTripEditSheet(context, trip, service: service),
              child: const Text('Edit trip'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Edit trip'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'Edited getaway');
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(find.text('Save changes'), findsOneWidget);
    expect(find.text('Edited getaway'), findsOneWidget);
    expect(find.textContaining('Your details are still here'), findsOneWidget);
  });
}
