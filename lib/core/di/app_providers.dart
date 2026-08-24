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
import '../../features/jukebox/data/services/spotify_auth_service.dart';
import '../../features/jukebox/data/services/spotify_player_service.dart';
import '../../features/jukebox/presentation/providers/jukebox_provider.dart';
import '../../features/jukebox/presentation/providers/music_stats_provider.dart';
import '../services/auth_service.dart';
import '../services/presence_service.dart';
import '../services/storage_service.dart';

final AuthService authService = AuthService();
final _authService = authService;
final _presenceService = PresenceService();
final _moodService = MoodService();
final _aiService = AIService();
final _guardianService = GuardianService();
final _spotifyAuth = SpotifyAuthService();
late final SpotifyPlayerService _spotifyPlayer;

final List<SingleChildWidget> appProviders = [
  ChangeNotifierProvider.value(value: _authService),
  Provider(create: (_) => StorageService()), // plain service, no notify
  Provider.value(value: _presenceService),
  Provider(create: (_) => DateIdeaService()),
  Provider(create: (_) => OurBooksService()),
  Provider.value(value: _guardianService),
  Provider.value(value: ChatService()),
  ChangeNotifierProvider(create: (_) => GardenProvider()),
  Provider.value(value: _moodService),
  ChangeNotifierProvider(create: (_) => MoodController(_moodService)),
  ChangeNotifierProvider.value(value: _aiService),
  ChangeNotifierProvider(
    create: (_) => GuardianController(
      _guardianService,
      moodService: _moodService,
      authService: _authService,
      aiService: _aiService,
    ),
  ),
  ChangeNotifierProvider.value(value: _spotifyAuth),
  ChangeNotifierProvider(
    create: (_) {
      _spotifyPlayer = SpotifyPlayerService(_spotifyAuth);
      // Start listening to link status once auth is ready; actual init is lazy (needs user gesture)
      _spotifyAuth.start();
      return _spotifyPlayer;
    },
  ),
  ChangeNotifierProvider(create: (_) => JukeboxProvider()),
  ChangeNotifierProvider(create: (_) => MusicStatsProvider()),
];
