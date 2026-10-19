import 'package:everglow/core/services/auth_service.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _NoLoginAuth extends FirebaseAuthPlatform {
  @override
  FirebaseAuthPlatform delegateFor({required FirebaseApp app}) => this;
  @override
  FirebaseAuthPlatform setInitialValues({
    PigeonUserDetails? currentUser,
    String? languageCode,
  }) => this;
  @override
  UserPlatform? get currentUser => null;
  @override
  Stream<UserPlatform?> authStateChanges() => const Stream.empty();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final savedUser in [null, 'clairjassen']) {
    test('normal disk restore stays unchanged ($savedUser)', () async {
      setupFirebaseCoreMocks();
      await Firebase.initializeApp();
      final previous = FirebaseAuthPlatform.instance;
      FirebaseAuthPlatform.instance = _NoLoginAuth();
      addTearDown(() => FirebaseAuthPlatform.instance = previous);
      SharedPreferences.setMockInitialValues({'current_user_name': ?savedUser});
      final auth = AuthService();
      addTearDown(auth.dispose);

      await SharedPreferences.getInstance();
      await Future<void>.delayed(Duration.zero);

      expect(auth.currentUser, savedUser);
      expect(auth.isAgentSession, isFalse);
      expect(auth.isSessionLoaded, isTrue);
      expect(auth.isReady, isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('current_user_name'), savedUser);
    });

    test('agent profile survives pending disk restore ($savedUser)', () async {
      setupFirebaseCoreMocks();
      await Firebase.initializeApp();
      final previous = FirebaseAuthPlatform.instance;
      FirebaseAuthPlatform.instance = _NoLoginAuth();
      addTearDown(() => FirebaseAuthPlatform.instance = previous);
      SharedPreferences.setMockInitialValues({'current_user_name': ?savedUser});
      final auth = AuthService();
      addTearDown(auth.dispose);
      auth.enableAgentSession(profile: 'breyan');
      var notifications = 0;
      auth.addListener(() => notifications++);

      await SharedPreferences.getInstance();
      await Future<void>.delayed(Duration.zero);

      expect(auth.currentUser, 'breyan');
      expect(auth.isAgentSession, isTrue);
      expect(auth.isReady, isTrue);
      expect(auth.isSessionLoaded, isTrue);
      expect(notifications, 0);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('current_user_name'), savedUser);
    });
  }

  test(
    'repeated router activation does not reenter session notifications',
    () async {
      setupFirebaseCoreMocks();
      await Firebase.initializeApp();
      final previous = FirebaseAuthPlatform.instance;
      FirebaseAuthPlatform.instance = _NoLoginAuth();
      addTearDown(() => FirebaseAuthPlatform.instance = previous);
      SharedPreferences.setMockInitialValues({});
      final auth = AuthService();
      // Let the constructor finish its asynchronous preference loading first.
      await SharedPreferences.getInstance();
      await Future<void>.delayed(Duration.zero);
      var notifications = 0;
      void redirect() {
        notifications++;
        if (notifications > 2) {
          fail('Session activation recursively notified the router');
        }
        auth.enableAgentSession(profile: auth.currentUser!);
      }

      auth.addListener(redirect);
      auth.enableAgentSession();
      auth.enableAgentSession();
      expect(notifications, 1);
      auth.enableAgentSession(profile: 'clairjassen');
      expect(notifications, 2);
      auth.removeListener(redirect);
      auth.dispose();
    },
  );
}
