import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart' as custom_theme;
import 'core/router/app_router.dart';
import 'services/auth_service.dart';
import 'services/presence_service.dart';
import 'services/storage_service.dart';
import 'features/books/data/services/our_books_service.dart';
import 'features/date_randomizer/data/services/date_idea_service.dart';
import 'features/guardian/data/services/guardian_service.dart';
import 'features/chat/data/services/chat_service.dart';
import 'features/daily_bloom/presentation/providers/garden_provider.dart';
import 'features/heartbeat/data/services/mood_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'features/jukebox/presentation/providers/jukebox_provider.dart';
import 'features/heartbeat/presentation/controllers/mood_controller.dart';
import 'features/guardian/presentation/controllers/guardian_controller.dart';
import 'features/watch_party/data/services/voice_chat_service.dart';
import 'features/watch_party/presentation/widgets/incoming_watch_party_banner.dart';

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

  runZonedGuarded(
    () => runApp(const EverglowApp()),
    (error, stack) {
      final msg = error.toString();
      if (msg.contains('onSnapshotUnsubscribe') || msg.contains('FIRESTORE INTERNAL ASSERTION')) {
        if (kDebugMode) debugPrint('[Firestore] Swallowed known race condition: $error');
      } else {
        if (kDebugMode) debugPrint('[Unhandled] $error\n$stack');
      }
    },
  );
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
        Provider(create: (_) => OurBooksService()),
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
      child: MaterialApp.router(
        title: 'Everglow v6.0.0',
        debugShowCheckedModeBanner: false,
        theme: custom_theme.AppTheme.gamifiedTheme,
        routerConfig: appRouter,
        builder: (context, child) => _AppRoot(child: child!),
      ),
    );
  }
}

/// Wraps every route (gateway, dashboard, chat, cinema, etc.)
/// so the silent incoming-call banner appears regardless of
/// which screen the user is on. Also keeps the global
/// `VoiceChatService.watchIncoming()` listener in sync with
/// the auth state.
class _AppRoot extends StatefulWidget {
  final Widget child;
  const _AppRoot({required this.child});

  @override
  State<_AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<_AppRoot> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncListener();
    });
  }

  void _syncListener() {
    final auth = context.read<AuthService>();
    final myUid = auth.uid;
    final partnerUid = auth.partnerUid;
    if (auth.isCoupleUser && myUid != null && myUid.isNotEmpty) {
      VoiceChatService.watchIncoming(
        myUid: myUid,
        partnerUid: partnerUid,
      );
    } else {
      VoiceChatService.clearIncomingWatcher();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, auth, _) {
        _syncListener();
        if (!auth.isCoupleUser) return widget.child;
        return Stack(
          children: [
            widget.child,
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: IgnorePointer(
                ignoring: false,
                child: IncomingWatchPartyBanner(),
              ),
            ),
          ],
        );
      },
    );
  }
}
