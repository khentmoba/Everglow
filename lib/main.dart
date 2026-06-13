import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart' as custom_theme;
import 'features/entry/presentation/pages/gateway_page.dart';
import 'services/auth_service.dart';
import 'services/presence_service.dart';
import 'services/storage_service.dart';
import 'features/cinema/data/services/our_cinema_service.dart';
import 'features/date_randomizer/data/services/date_idea_service.dart';
import 'features/guardian/data/services/guardian_service.dart';
import 'screens/login_screen.dart';
import 'screens/timeline_screen.dart';
import 'features/chat/data/services/chat_service.dart';
import 'features/daily_bloom/presentation/providers/garden_provider.dart';
import 'features/heartbeat/data/services/mood_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'features/jukebox/presentation/providers/jukebox_provider.dart';
import 'features/heartbeat/presentation/controllers/mood_controller.dart';
import 'features/guardian/presentation/controllers/guardian_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await dotenv.load(fileName: "assets/env.txt");
    print("Environment variables loaded successfully");
  } catch (e) {
    print("Warning: Could not load env.txt file: $e. Using fallbacks.");
  }

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Enable Firestore persistence for all platforms (including Web)
  // This fixes the "always buffering" issue and makes data "always there"
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );
  print("Firestore persistence enabled for robust real-time experience");

  
  runApp(const EverglowApp());
}

class EverglowApp extends StatelessWidget {
  const EverglowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => StorageService()),
        Provider(create: (_) => PresenceService()),
        Provider(create: (_) => DateIdeaService()),
        Provider(create: (_) => OurCinemaService()),
        Provider(create: (_) => GuardianService()),
        Provider(create: (_) => ChatService()),
        ChangeNotifierProvider(create: (_) => GardenProvider()),
        Provider(create: (_) => MoodService()),
        ChangeNotifierProvider(
          create: (context) => MoodController(context.read<MoodService>()),
        ),
        ChangeNotifierProvider(
          create: (context) => GuardianController(context.read<GuardianService>()),
        ),
        ChangeNotifierProvider(create: (_) => JukeboxProvider()),
      ],
      child: MaterialApp(
        title: 'Everglow v1.2.0',
        debugShowCheckedModeBanner: false,
        theme: custom_theme.AppTheme.gamifiedTheme,
        home: const GatewayPage(),
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);

    if (authService.isAuthenticated) {
      return const TimelineScreen();
    } else {
      return const LoginScreen();
    }
  }
}
