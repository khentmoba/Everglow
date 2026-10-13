import 'package:everglow/core/theme/app_theme.dart';
import 'package:everglow/features/ai/data/services/ai_service.dart';
import 'package:everglow/features/ai/domain/repositories/ai_conversation_repo_interface.dart';
import 'package:everglow/features/ai/domain/repositories/ai_memory_repo_interface.dart';
import 'package:everglow/features/ai/presentation/screens/motchi_preferences_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _Memory implements IAIMemoryRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Conversation implements IAIConversationRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Companion extends AIService {
  _Companion()
    : super(memoryRepo: _Memory(), conversationRepo: _Conversation());
  bool fail = false;
  int reads = 0;
  final saved = <Map<String, dynamic>>[];

  @override
  Future<Map<String, dynamic>> companionOperation(
    String operation, {
    Map<String, dynamic>? value,
  }) async {
    if (operation == 'load') reads++;
    if (fail) throw StateError('Demo unavailable');
    if (value != null) saved.add(Map.of(value));
    return {
      'preferences': {
        'nudges': 'daily',
        'digests': true,
        'quietStart': 22,
        'quietEnd': 8,
      },
    };
  }
}

void main() {
  for (final width in [320.0, 810.0]) {
    testWidgets('preferences save explicitly and load once at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final ai = _Companion();
      await tester.pumpWidget(
        ChangeNotifierProvider<AIService>.value(
          value: ai,
          child: MaterialApp(
            theme: AppTheme.gamifiedTheme,
            home: const MotchiPreferencesScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(ai.reads, 1);
      expect(ai.saved, isEmpty);
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      expect(ai.reads, 1, reason: 'changing controls must not fetch or save');
      expect(ai.saved, isEmpty);
      await tester.ensureVisible(find.text('Save preferences'));
      await tester.tap(find.text('Save preferences'));
      await tester.pumpAndSettle();
      expect(ai.saved.single['digests'], false);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'failed loads allow retry and failed saves keep the edited controls',
    (tester) async {
      final ai = _Companion()..fail = true;
      await tester.pumpWidget(
        ChangeNotifierProvider<AIService>.value(
          value: ai,
          child: MaterialApp(
            theme: AppTheme.gamifiedTheme,
            home: const MotchiPreferencesScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Could not load your preferences. Try again.'),
        findsOneWidget,
      );
      ai.fail = false;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      ai.fail = true;
    await tester.scrollUntilVisible(find.text('Save preferences'), 200);
      await tester.tap(find.text('Save preferences'));
      await tester.pumpAndSettle();
      expect(
        find.text('Could not save your preferences. Try again.'),
        findsOneWidget,
      );
      expect(ai.reads, 2);
      expect(tester.takeException(), isNull);
    },
  );
}
