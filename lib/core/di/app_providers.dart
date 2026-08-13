import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../features/ai/data/services/ai_service.dart';
import '../../features/books/data/services/our_books_service.dart';
import '../../features/chat/data/services/chat_service.dart';
import '../../features/daily_bloom/presentation/providers/garden_provider.dart';
import '../../features/date_randomizer/data/services/date_idea_service.dart';
import '../../features/guardian/data/services/guardian_service.dart';
import '../../features/guardian/presentation/controllers/guardian_controller.dart';
import '../../features/heartbeat/data/services/mood_service.dart';
import '../../features/heartbeat/presentation/controllers/mood_controller.dart';
import '../../features/jukebox/presentation/providers/jukebox_provider.dart';
import '../../features/jukebox/presentation/providers/music_stats_provider.dart';
import '../services/auth_service.dart';
import '../services/presence_service.dart';
import '../services/storage_service.dart';

/// App-wide dependency graph.
///
/// This module is the composition root: it is the only place that knows how
/// feature services and controllers fit together. Features stay isolated from
/// the entry point, and [EverglowApp] only installs this list.
final List<SingleChildWidget> appProviders = [
  ChangeNotifierProvider(create: (_) => AuthService()),
  ChangeNotifierProvider(create: (_) => StorageService()),
  Provider(create: (_) => PresenceService()),
  Provider(create: (_) => DateIdeaService()),
  Provider(create: (_) => OurBooksService()),
  // GuardianService and ChatService are singletons, use the existing instance.
  Provider.value(value: GuardianService()),
  Provider.value(value: ChatService()),
  ChangeNotifierProvider(create: (_) => GardenProvider()),
  Provider(create: (_) => MoodService()),
  ChangeNotifierProvider(
    create: (context) => MoodController(context.read<MoodService>()),
  ),
  ChangeNotifierProvider(create: (_) => AIService()),
  ChangeNotifierProvider(
    create: (context) => GuardianController(
      context.read<GuardianService>(),
      moodService: context.read<MoodService>(),
      authService: context.read<AuthService>(),
    )..setAIService(context.read<AIService>()),
  ),
  ChangeNotifierProvider(create: (_) => JukeboxProvider()),
  ChangeNotifierProvider(create: (_) => MusicStatsProvider()),
];
