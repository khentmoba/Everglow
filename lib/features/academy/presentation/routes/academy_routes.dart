import 'package:go_router/go_router.dart';
import '../../../../core/router/deferred_route.dart';
import '../../../../core/router/route_helpers.dart';

import '../../data/models/academy_question.dart';
import '../../data/models/game_match.dart';
import '../screens/academy_hub_screen.dart' deferred as academy_lib;

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
