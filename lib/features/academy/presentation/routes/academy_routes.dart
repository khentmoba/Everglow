import 'package:go_router/go_router.dart';
import '../../../../core/router/deferred_route.dart';
import '../../../../core/router/route_helpers.dart';

import '../../data/models/academy_question.dart';
import '../../data/models/game_match.dart';
import '../screens/academy_hub_screen.dart' deferred as academy_lib;

/// Routes owned by the academy feature.
///
/// The whole hub (and with it solo study, the head-to-head board and the
/// podium) rides one deferred chunk: the four screens share question/match
/// models and navigation, so splitting them would download the same models
/// twice for no boot win.
final List<GoRoute> academyRoutes = [
  GoRoute(
    path: '/academy',
    builder: (_, _) => DeferredRouteLoader(
      label: 'Academy',
      loadLibrary: academy_lib.loadLibrary,
      builder: () => academy_lib.AcademyHubScreen(),
    ),
    routes: [
      GoRoute(
        path: 'solo',
        builder: (_, state) {
          final args = extraOf<SoloStudyArgs>(state);
          if (args == null) return missingExtraPage(state);
          return academy_lib.SoloStudyScreen(
            questions: args.questions,
            category: args.category,
            topic: args.topic,
          );
        },
      ),
      GoRoute(
        path: 'match',
        builder: (_, state) {
          final args = extraOf<GameBoardArgs>(state);
          if (args == null) return missingExtraPage(state);
          return academy_lib.GameBoardScreen(
            matchId: args.matchId,
            username: args.username,
            questions: args.questions,
          );
        },
      ),
      GoRoute(
        path: 'podium',
        builder: (_, state) {
          final match = extraOf<GameMatch>(state);
          if (match == null) return missingExtraPage(state);
          return academy_lib.PodiumScreen(match: match);
        },
      ),
    ],
  ),
];

/// Args for [SoloStudyScreen].
class SoloStudyArgs {
  final List<AcademyQuestion> questions;
  final String category;
  final String topic;

  SoloStudyArgs({
    required this.questions,
    required this.category,
    this.topic = '',
  });
}

/// Args for [GameBoardScreen].
class GameBoardArgs {
  final String matchId;
  final String username;
  final List<AcademyQuestion> questions;

  GameBoardArgs({
    required this.matchId,
    required this.username,
    required this.questions,
  });
}
