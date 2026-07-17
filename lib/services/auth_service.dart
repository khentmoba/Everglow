import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/config/env_config.dart';
import '../features/xp/data/services/xp_service.dart';
import '../features/dashboard/data/services/letterbox_service.dart';
import '../core/utils/logger.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? _user;
  String? _currentUser;
  String? _partnerUid;
  String? _partnerNameResolved;
  bool _hasSyncedUserDoc = false;
  String? _lastAuthError;

  AuthService() {
    _loadSession();
    _auth.authStateChanges().listen((User? user) async {
      _user = user;
      _hasSyncedUserDoc = false;
      if (user != null && _currentUser != null) {
        await _syncUserDoc();
      }
      notifyListeners();
    });
  }

  Future<void> _loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    _currentUser = prefs.getString('current_user_name');
    if (_currentUser != null) {
      Logger.i("Restored session for: $_currentUser");
      notifyListeners();
      // If auth state already fired before we loaded the session,
      // sync the user doc now that _currentUser is available.
      if (_auth.currentUser != null && !_hasSyncedUserDoc) {
        await _syncUserDoc();
      }
    }
  }

  Future<void> _saveSession(String? name) async {
    final prefs = await SharedPreferences.getInstance();
    if (name != null) {
      await prefs.setString('current_user_name', name);
    } else {
      await prefs.remove('current_user_name');
    }
  }

  User? get user => _user;
  bool get isAuthenticated => _user != null;
  String? get currentUser => _currentUser;
  String? get uid => _auth.currentUser?.uid;

  /// True once both Firebase Auth and SharedPreferences have resolved.
  /// Dashboard and partner-dependent features should wait for this.
  bool get isReady => _user != null && _currentUser != null;

  /// Dynamically resolved partner UID from the /users collection.
  /// Populated after login via [_syncUserDoc].
  String? get partnerUid => _partnerUid;

  /// Partner display name resolved alongside [partnerUid].
  String get partnerName => _partnerNameResolved ?? 'Partner';

  String? get partnerUsername {
    if (_currentUser == 'clairjassen') return 'khentsgdz';
    if (_currentUser == 'khentsgdz') return 'clairjassen';
    return null;
  }

  /// True if the signed-in user is a cinema-only profile (Breyan, Octagram).
  /// They get access to the Cinema feature but not the partner-only data.
  bool get isCinemaOnlyUser =>
      _currentUser == 'breyan' || _currentUser == 'octagram';

  /// True if the signed-in user is one half of the couple (Khent or Clair).
  /// These two accounts share the "Our Cinema" list; everyone else does not.
  bool get isCoupleUser =>
      _currentUser == 'khentsgdz' || _currentUser == 'clairjassen';

  /// Last authentication error message, if any. Cleared on successful login.
  String? get lastAuthError => _lastAuthError;

  void setCurrentUser(String? name) {
    _currentUser = name;
    _saveSession(name);
    ensureAuthenticated(); // Ensure we have a Firebase session
    notifyListeners();
  }

  /// Ensures the user is authenticated with a real account based on their passcode
  Future<void> loginWithPasscode(String username) async {
    String email;
    String password;

    if (username == 'clairjassen') {
      email = EnvConfig.clairEmail;
      password = EnvConfig.clairPassword;
      if (email.isEmpty || password.isEmpty) {
        Logger.w("CLAIR environment variables not set. Using local/default credentials.");
        email = "clairjassen@scrapbook.local";
        password = "111111";
      }
    } else if (username == 'khentsgdz') {
      email = EnvConfig.khentEmail;
      password = EnvConfig.khentPassword;
      if (email.isEmpty || password.isEmpty) {
        Logger.w("KHENT environment variables not set. Using local/default credentials.");
        email = "khentplaysmoba@gmail.com";
        password = "297864503";
      }
    } else if (username == 'breyan') {
      email = EnvConfig.breyanEmail;
      password = EnvConfig.breyanPassword;
      if (email.isEmpty || password.isEmpty) {
        Logger.w("BREYAN environment variables not set. Using local/default credentials.");
        email = "breyan@scrapbook.local";
        password = "91329132";
      }
    } else if (username == 'octagram') {
      email = EnvConfig.octagramEmail;
      password = EnvConfig.octagramPassword;
      if (email.isEmpty || password.isEmpty) {
        Logger.w("OCTAGRAM environment variables not set. Using local/default credentials.");
        email = "octagram@scrapbook.local";
        password = "80808080";
      }
    } else {
      throw StateError('Unknown username: $username');
    }

    try {
      Logger.d("Attempting login for $username ($email)...");
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      _currentUser = username;
      await _saveSession(username);
      await _syncUserDoc();
      _lastAuthError = null;
      Logger.i("Successfully logged in as $username (UID: ${_auth.currentUser?.uid})");
      notifyListeners();
    } on FirebaseAuthException catch (e) {
      Logger.e('Login failed with FirebaseAuthException', error: e);
      if (e.code == 'user-not-found' || e.code == 'invalid-credential' || e.code == 'invalid-email') {
        try {
          await _auth.createUserWithEmailAndPassword(email: email, password: password);
          _currentUser = username;
          await _saveSession(username);
          await _syncUserDoc();
          _lastAuthError = null;
          Logger.i("Successfully registered and logged in as new user: $username (UID: ${_auth.currentUser?.uid})");
          notifyListeners();
        } catch (regErr) {
          _lastAuthError = 'Account creation failed. Please try again.';
          Logger.e("Registration error for $username", error: regErr);
          await ensureAuthenticated();
        }
      } else {
        _lastAuthError = 'Authentication failed: ${e.message ?? e.code}';
        await ensureAuthenticated();
      }
    } catch (e) {
      _lastAuthError = 'Login error. Falling back to guest access.';
      Logger.e("General auth error during passcode login", error: e);
      await ensureAuthenticated();
    }
  }

  /// Ensures the user is authenticated with Firebase (anonymously if needed)
  Future<void> ensureAuthenticated() async {
    if (_auth.currentUser == null) {
      try {
        Logger.d("Fallback: Signing in anonymously...");
        await _auth.signInAnonymously();
        Logger.i("Authenticated anonymously (UID: ${_auth.currentUser?.uid})");
      } catch (e) {
        Logger.e("Anonymous authentication failed", error: e);
      }
    }
  }

  /// Writes/updates the /users/{uid} document and resolves the partner's UID
  /// dynamically from Firestore. This replaces the old hard-coded UID system
  /// and is resilient to account recreations.
  Future<void> _syncUserDoc() async {
    final myUid = _auth.currentUser?.uid;
    if (myUid == null || _currentUser == null) return;
    if (_hasSyncedUserDoc) return;

    try {
      final db = FirebaseFirestore.instance;

      // Write/update my user doc
      await db.collection('users').doc(myUid).set({
        'username': _currentUser,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Resolve partner dynamically
      await _resolvePartnerInfo();

      // Initialize XP progress doc (no-op if already exists)
      XPService().initializeProgress(myUid);

      // Seed a sample letterbox note if the collection is empty
      LetterboxService().ensureSeeded();

      _hasSyncedUserDoc = true;
    } catch (e) {
      Logger.e("AuthService._syncUserDoc failed", error: e);
    }
  }

  /// Queries /users to find the partner's UID by username. If the partner's
  /// account was recreated, this automatically finds their new UID.
  Future<void> _resolvePartnerInfo() async {
    final partnerUser = partnerUsername;
    if (partnerUser == null) {
      _partnerUid = null;
      _partnerNameResolved = null;
      notifyListeners();
      return;
    }

    try {
      final db = FirebaseFirestore.instance;
      final query = await db
          .collection('users')
          .where('username', isEqualTo: partnerUser)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        _partnerUid = query.docs.first.id;
        _partnerNameResolved =
            partnerUser == 'khentsgdz' ? 'Khent' : 'Clair';
      } else {
        _partnerUid = null;
        _partnerNameResolved = null;
      }
    } catch (e) {
      Logger.e("AuthService._resolvePartnerInfo failed", error: e);
      _partnerUid = null;
      _partnerNameResolved = null;
    }

    notifyListeners();
  }

  // Option 2: Restricted list of allowed users
  final List<String> allowedUsernames = ['khentsgdz', 'clairjassen', 'breyan', 'octagram'];

  // Modern Nostalgia: We use simple username login by mapping to a local domain
  Future<String?> login(String username, String password) async {
    final cleanUsername = username.trim().toLowerCase();
    
    // Check if the username is allowed
    if (!allowedUsernames.contains(cleanUsername)) {
      return "Access Denied: This is a private scrapbook.";
    }

    try {
      final String email = "$cleanUsername@scrapbook.local";
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      _currentUser = cleanUsername;
      await _saveSession(cleanUsername);
      await _syncUserDoc();
      return null; // Success
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        // If user doesn't exist AND is in our allowed list, we register them
        return await register(cleanUsername, password);
      }
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> register(String username, String password) async {
    try {
      final String email = "$username@scrapbook.local";
      await _auth.createUserWithEmailAndPassword(email: email, password: password);
      _currentUser = username;
      await _saveSession(username);
      await _syncUserDoc();
      return null; // Success
    } on FirebaseAuthException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
    _currentUser = null;
    await _saveSession(null);
    notifyListeners();
  }
}
