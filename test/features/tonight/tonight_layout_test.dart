import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:everglow/core/services/auth_service.dart';
import 'package:everglow/core/theme/app_theme.dart';
import 'package:everglow/features/dashboard/presentation/widgets/tonight_card.dart';
import 'package:everglow/features/tonight/data/models/tonight_decision.dart';
import 'package:everglow/features/tonight/data/models/tonight_option.dart';
import 'package:everglow/features/tonight/presentation/screens/tonight_screen.dart';

class _DemoAuth extends ChangeNotifier implements AuthService {
  @override
  String get currentUser => 'khentsgdz';
  @override
  String get partnerName => 'Clair';
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

TonightDecision _decision(String state) {
  final now = DateTime(2026, 10, 3, 20);
  return TonightDecision(
    id: 'demo',
    options: state == 'empty'
        ? []
        : const [
            TonightOption(
              id: 'movie',
              type: TonightOptionType.movie,
              title: 'A very long movie title for a lovely evening together',
              subtitle: 'From our Cinema watchlist',
              description:
                  'A magical journey through a world of spirits and wonderful memories.',
            ),
            TonightOption(
              id: 'date',
              type: TonightOptionType.date,
              title: 'Cook homemade pasta together by candlelight',
              subtitle: 'A cozy night in',
              description:
                  'Cook something lovely, put on our favorite songs, and take it slow.',
              targetRoute: '/calendar',
            ),
            TonightOption(
              id: 'game',
              type: TonightOptionType.game,
              title: 'Scribble Together',
              description:
                  'One draws, one guesses. A little friendly competition for two.',
            ),
          ],
    status: state == 'match'
        ? TonightStatus.decided
        : state == 'planned'
        ? TonightStatus.planned
        : TonightStatus.voting,
    votes: state == 'tie'
        ? {'khentsgdz': 'movie', 'clairjassen': 'date'}
        : state == 'waiting'
        ? {'khentsgdz': 'movie'}
        : state == 'match' || state == 'planned'
        ? {'khentsgdz': 'date', 'clairjassen': 'date'}
        : {},
    winnerOptionId: state == 'match' || state == 'planned' ? 'date' : null,
    planTime: state == 'planned' ? now : null,
    createdAt: now,
    updatedAt: now,
  );
}

Future<void> _pump(
  WidgetTester tester,
  String state, {
  double width = 390,
  bool dashboard = false,
  double scale = 1,
}) async {
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => dashboard
            ? Scaffold(
                body: Padding(
                  padding: const EdgeInsets.all(16),
                  child: TonightCard(previewDecision: _decision(state)),
                ),
              )
            : TonightScreen(previewDecision: _decision(state)),
      ),
      GoRoute(
        path: '/tonight',
        builder: (_, _) => const Scaffold(body: Text('Tonight route')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ChangeNotifierProvider<AuthService>(
      create: (_) => _DemoAuth(),
      child: MaterialApp.router(
        theme: AppTheme.gamifiedTheme,
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('dashboard arrow opens Tonight', (tester) async {
    await _pump(tester, 'voting', dashboard: true);
    await tester.tap(find.byTooltip('Choose tonight'));
    await tester.pumpAndSettle();
    expect(find.text('Tonight route'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  for (final width in [320.0, 600.0, 768.0, 1024.0]) {
    for (final state in [
      'empty',
      'voting',
      'waiting',
      'tie',
      'match',
      'planned',
    ]) {
      testWidgets('$state fits ${width.toInt()}px phone/tablet', (
        tester,
      ) async {
        await _pump(tester, state, width: width);
        expect(tester.takeException(), isNull);
      });
      testWidgets('dashboard $state fits ${width.toInt()}px', (tester) async {
        await _pump(tester, state, width: width, dashboard: true);
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets('tie action stays below the message on a small phone', (
    tester,
  ) async {
    await _pump(tester, 'tie', width: 320);
    expect(
      tester.getTopLeft(find.text('Flip a coin')).dy,
      greaterThan(
        tester
            .getBottomLeft(
              find.text('Choose one together below, or leave it to chance.'),
            )
            .dy,
      ),
    );
  });
  testWidgets('match focuses the winner and time selection still works', (
    tester,
  ) async {
    await _pump(tester, 'match');
    expect(find.text('It’s a match.'), findsOneWidget);
    expect(find.text('Scribble Together'), findsNothing);
    await tester.tap(find.widgetWithText(ChoiceChip, '7:00 PM'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '7:00 PM'))
          .selected,
      isTrue,
    );
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '8:00 PM'))
          .selected,
      isFalse,
    );
    expect(tester.takeException(), isNull);
  });
  for (final state in ['tie', 'match', 'planned']) {
    testWidgets('$state handles larger text', (tester) async {
      await _pump(tester, state, width: 320, scale: 1.5);
      expect(tester.takeException(), isNull);
    });
  }
}
