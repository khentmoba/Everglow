import 'dart:async';

import 'package:everglow/features/journal/data/models/journal_entry.dart';
import 'package:everglow/features/journal/data/services/journal_service.dart';
import 'package:everglow/features/journal/presentation/widgets/add_journal_entry_dialog.dart';
import 'package:everglow/features/xp/data/services/xp_service.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../support/firestore_test_fakes.dart';

class _Auth extends FirebaseAuthPlatform {
  @override
  FirebaseAuthPlatform delegateFor({required FirebaseApp app}) => this;
  @override
  FirebaseAuthPlatform setInitialValues({
    PigeonUserDetails? currentUser,
    String? languageCode,
  }) => this;
  @override
  UserPlatform get currentUser => _User(this);
}

class _User extends UserPlatform {
  _User(FirebaseAuthPlatform auth)
    : super(
        auth,
        _MultiFactor(auth),
        PigeonUserDetails(
          userInfo: PigeonUserInfo(
            uid: 'demo',
            isAnonymous: false,
            isEmailVerified: true,
          ),
          providerData: [],
        ),
      );
}

class _MultiFactor extends MultiFactorPlatform {
  _MultiFactor(super.auth);
}

class _Xp extends Fake implements XPService {
  final pending = Completer<bool>();
  var awards = 0;
  @override
  Future<bool> awardJournal(String uid) {
    awards++;
    return pending.future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    final previous = FirebaseAuthPlatform.instance;
    FirebaseAuthPlatform.instance = _Auth();
    addTearDown(() => FirebaseAuthPlatform.instance = previous);
  });
  testWidgets(
    'confirmed save closes and clears drafts while XP is still pending',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final entries = TestCollection(failWrites: false);
      final xp = _Xp();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => AddJournalEntryDialog(
                    author: 'demo',
                    service: JournalService(db: TestFirestore(entries)),
                    xpService: xp,
                  ),
                ),
                child: const Text('Write'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Write'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(0), 'Demo entry');
      await tester.enterText(find.byType(TextField).at(1), 'Saved demo words');
      await tester.pump(const Duration(milliseconds: 600));
      await tester.ensureVisible(find.text('Save Entry ✨'));
      await tester.tap(find.text('Save Entry ✨'));
      await tester.pumpAndSettle();
      expect(entries.writeAttempts, 1);
      expect(xp.awards, 1);
      expect(xp.pending.isCompleted, isFalse);
      expect(find.byType(AddJournalEntryDialog), findsNothing);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('draft:journal:new:content'), isNull);
      xp.pending.completeError(Exception('XP unavailable'));
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );
  test('journal mutations propagate rejected writes', () async {
    final service = JournalService(db: TestFirestore(TestCollection()));
    final entry = JournalEntry(
      id: 'demo',
      title: 'Demo',
      content: 'Demo words',
      author: 'demo',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    await expectLater(service.add(entry), throwsA(anything));
    await expectLater(service.update(entry), throwsA(anything));
    await expectLater(service.delete(entry.id), throwsA(anything));
    await expectLater(service.togglePin(entry.id, true), throwsA(anything));
    await expectLater(service.toggleLock(entry.id, true), throwsA(anything));
  });
  testWidgets(
    'rejected journal save retains the dialog, words and persisted draft for retry',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final entries = TestCollection();
      final service = JournalService(db: TestFirestore(entries));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AddJournalEntryDialog(author: 'demo', service: service),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(0), 'Demo entry');
      await tester.enterText(
        find.byType(TextField).at(1),
        'Keep these demo words',
      );
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString('draft:journal:new:content'),
        'Keep these demo words',
      );
      await tester.ensureVisible(find.text('Save Entry ✨'));
      await tester.tap(find.text('Save Entry ✨'));
      await tester.pumpAndSettle();
      expect(find.byType(AddJournalEntryDialog), findsOneWidget);
      expect(find.text('Keep these demo words'), findsOneWidget);
      expect(find.textContaining('Could not save your page'), findsOneWidget);
      expect(
        prefs.getString('draft:journal:new:content'),
        'Keep these demo words',
      );
      expect(entries.writeAttempts, 1);
      await tester.ensureVisible(find.text('Save Entry ✨'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save Entry ✨'));
      await tester.pumpAndSettle();
      expect(entries.writeAttempts, 2);
    },
  );
}
