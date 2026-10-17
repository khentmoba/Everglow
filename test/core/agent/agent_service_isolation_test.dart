// SDK sealed types are implemented only as network-free test doubles.
// ignore_for_file: subtype_of_sealed_class
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:everglow/core/agent/agent_mode.dart';
import 'package:everglow/core/agent/agent_fixtures.dart';
import 'package:everglow/features/books/data/models/book_item.dart';
import 'package:everglow/features/books/data/services/our_books_service.dart';
import 'package:everglow/features/money/data/services/money_service.dart';
import 'package:everglow/features/subs/data/services/subs_service.dart';
import 'package:everglow/features/trip_kit/data/models/trip.dart';
import 'package:everglow/features/trip_kit/data/services/trip_kit_service.dart';

class _LiveFirestore implements FirebaseFirestore {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Demo touched live Firestore');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'demo reads, cache access and every write avoid the live Firebase connection',
    () async {
      SharedPreferences.setMockInitialValues({
        'cached_our_books': '[{"title":"private sentinel"}]',
      });
      AgentMode.isActive.value = true;
      addTearDown(() => AgentMode.isActive.value = false);
      final db = _LiveFirestore();
      final month = DateTime(2026, 10);
      final money = MoneyService(db: db);
      expect((await money.watchMonth(month).first).map((e) => e.id), [
        'demo_income',
        'demo_expense',
      ]);
      expect(await money.watchLimits().first, AgentFixtures.demoBudgets);
      await money.add(AgentFixtures.demoMoney(month).first);
      await money.delete('private');
      await money.setLimit('Food', 1);
      await money.removeLimit('Food');
      final subs = SubsService(db: db);
      expect(await subs.watchAll().first, AgentFixtures.demoSubscriptions);
      await subs.add(AgentFixtures.demoSubscriptions.first);
      await subs.update(
        AgentFixtures.demoSubscriptions.first,
        original: AgentFixtures.demoSubscriptions.first,
      );
      await subs.delete('private');
      final trips = TripKitService(db: db);
      final trip = AgentFixtures.demoTrips.first;
      expect(await trips.watchAll().first, AgentFixtures.demoTrips);
      expect(await trips.watchOne(trip.id).first, trip);
      expect(await trips.create(trip), trip.id);
      await trips.updateDetails(trip);
      await trips.addPackingItem(
        'private',
        const TripPackItem(id: 'demo-pack', label: 'Demo item'),
      );
      await trips.addExpense(
        'private',
        const TripExpense(id: 'demo-expense', label: 'Demo expense'),
      );
      await trips.addPlace(
        'private',
        const TripPlace(id: 'demo-place', name: 'Demo place'),
      );
      await trips.delete('private');
      final books = OurBooksService(firestore: db);
      expect(await books.getOurBooksStream().first, AgentFixtures.demoBooks);
      expect(await books.getCachedOurBooks(), AgentFixtures.demoBooks);
      expect(
        await books.getOurBooksByAdderPreviewStream('khentsgdz').first,
        AgentFixtures.demoBooks,
      );
      await books.addToOurBooks(
        BookItem(
          id: 'demo',
          workKey: 'demo',
          title: 'demo',
          status: 'to-read',
          addedAt: DateTime(2026, 2),
        ),
        'khentsgdz',
      );
      await books.setReadFlag(
        workKey: 'private',
        userName: 'khentsgdz',
        read: true,
      );
      await books.removeFromOurBooks('private');
    },
  );
}
