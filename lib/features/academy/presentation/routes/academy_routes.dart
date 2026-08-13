import 'package:go_router/go_router.dart';
import '../../../../core/router/route_helpers.dart';

import '../../models/academy_question.dart';
import '../../models/game_match.dart';
import '../../screens/academy_hub_screen.dart';
import '../../screens/game_board_screen.dart';
import '../../screens/podium_screen.dart';
import '../../screens/solo_study_screen.dart';

/// Routes owned by the academy feature.
final List<GoRoute> academyRoutes = [
  GoRoute(
    path: '/academy',
    builder: (_, _) => const AcademyHubScreen(),
    routes: [
      GoRoute(
        path: 'solo',
        builder: (_, state) {
          final args = extraOf<SoloStudyArgs>(state);
          if (args == null) return missingExtraPage(state);
          return SoloStudyScreen(
            questions: args.questions,
            category: args.category,
          );
        },
      ),
      GoRoute(
        path: 'match',
        builder: (_, state) {
          final args = extraOf<GameBoardArgs>(state);
          if (args == null) return missingExtraPage(state);
          return GameBoardScreen(
            matchId: args.matchId,
            userId: args.userId,
            questions: args.questions,
          );
        },
      ),
      GoRoute(
        path: 'podium',
        builder: (_, state) {
          final match = extraOf<GameMatch>(state);
          if (match == null) return missingExtraPage(state);
          return PodiumScreen(match: match);
        },
      ),
    ],
  ),
];

/// Args for [SoloStudyScreen].
class SoloStudyArgs {
  final List<AcademyQuestion> questions;
  final String category;

  SoloStudyArgs({required this.questions, required this.category});
}

/// Args for [GameBoardScreen].
class GameBoardArgs {
  final String matchId;
  final String userId;
  final List<AcademyQuestion> questions;

  GameBoardArgs({
    required this.matchId,
    required this.userId,
    required this.questions,
  });
}
