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
import '../../features/xp/data/services/xp_service.dart';
import '../../features/jukebox/data/services/spotify_auth_service.dart';
import '../../features/jukebox/data/services/spotify_player_service.dart';
import '../../features/jukebox/presentation/providers/artist_showdown_provider.dart';
import '../../features/jukebox/presentation/providers/jukebox_provider.dart';
import '../../features/jukebox/presentation/providers/music_stats_provider.dart';
import '../services/auth_service.dart';
import '../services/offline_media/offline_media_service.dart';
import '../services/presence_service.dart';

final AuthService authService = AuthService();

final List<SingleChildWidget> appProviders = [
  ChangeNotifierProvider.value(value: authService),
  Provider(create: (_) => PresenceService(), lazy: true),
  Provider(create: (_) => DateIdeaService(), lazy: true),
  Provider(create: (_) => OurBooksService(), lazy: true),
  Provider(create: (_) => GuardianService(), lazy: true),
  Provider(create: (_) => ChatService(), lazy: true),
  ChangeNotifierProvider(create: (_) => GardenProvider()),
  Provider(create: (_) => MoodService(), lazy: true),
  ChangeNotifierProvider(
    create: (ctx) => MoodController(
      ctx.read<MoodService>(),
      awardMoodXp: (uid) => XPService().awardMood(uid),
    ),
  ),
  ChangeNotifierProvider(create: (_) => AIService()),
  ChangeNotifierProvider(
    create: (ctx) => GuardianController(
      ctx.read<GuardianService>(),
      moodService: ctx.read<MoodService>(),
      authService: ctx.read<AuthService>(),
      aiService: ctx.read<AIService>(),
    ),
  ),
  ChangeNotifierProvider(create: (_) => SpotifyAuthService()),
  ChangeNotifierProvider(
    create: (ctx) {
      final spotifyAuth = ctx.read<SpotifyAuthService>();
      final player = SpotifyPlayerService(spotifyAuth);
      spotifyAuth.start();
      return player;
    },
  ),
  ChangeNotifierProvider(
    create: (ctx) => JukeboxProvider(
      authService: ctx.read<AuthService>(),
      awardListenXp: (uid) => XPService().awardListen(uid),
    ),
  ),
  ChangeNotifierProvider(create: (_) => MusicStatsProvider(surfaceActive: false)),
  ChangeNotifierProvider(create: (_) => ArtistShowdownProvider()),
  ChangeNotifierProvider.value(value: OfflineMediaService.instance),
];
