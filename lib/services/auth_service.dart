import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? _user;
  String? _currentUser;

  // Specific UIDs provided for robust partner identification
  static const String clairUid = 'bqS6Y5JlzuUB1YcbzUUK7MRpEqA2';
  static const String khentUid = 'nitw0mxAR9WtxtzQtLNHYWRjENj2';

  AuthService() {
    _loadSession();
    _auth.authStateChanges().listen((User? user) {
      _user = user;
      notifyListeners();
    });
  }

  Future<void> _loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    _currentUser = prefs.getString('current_user_name');
    if (_currentUser != null) {
      print("Restored session for: $_currentUser");
      notifyListeners();
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

  String? get partnerUid {
    final currentUid = uid;
    if (currentUid == clairUid) return khentUid;
    if (currentUid == khentUid) return clairUid;
    return null;
  }

  String get partnerName {
    final currentUid = uid;
    if (currentUid == clairUid) return 'Khent';
    if (currentUid == khentUid) return 'Clair';
    return 'Partner';
  }

  String? get partnerUsername {
    if (_currentUser == 'clairjassen') return 'khentsgdz';
    if (_currentUser == 'khentsgdz') return 'clairjassen';
    return null;
  }

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
      email = "clairjassen@scrapbook.local";
      password = "111111";
    } else if (username == 'khentsgdz') {
      email = "khentplaysmoba@gmail.com";
      password = "297864503";
    } else {
      // Fallback
      email = "$username@scrapbook.local";
      password = "everglow-sanctuary-2026";
    }

    try {
      print("Attempting login for $username ($email)...");
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      _currentUser = username;
      await _saveSession(username);
      print("Successfully logged in as $username (UID: ${_auth.currentUser?.uid})");
      notifyListeners();
    } on FirebaseAuthException catch (e) {
      print("FirebaseAuthException during login: ${e.code} - ${e.message}");
      if (e.code == 'user-not-found' || e.code == 'invalid-credential' || e.code == 'invalid-email') {
        // Auto-register if it's the first time
        print("User not found or invalid credentials, attempting to register $email...");
        try {
          await _auth.createUserWithEmailAndPassword(email: email, password: password);
          _currentUser = username;
          await _saveSession(username);
          print("Successfully registered and logged in as new user: $username (UID: ${_auth.currentUser?.uid})");
          notifyListeners();
        } catch (regErr) {
          print("Registration error for $username: $regErr");
          // Fallback to anonymous if registration fails
          await ensureAuthenticated();
        }
      } else {
        print("Auth error: ${e.message}");
        await ensureAuthenticated();
      }
    } catch (e) {
      print("General auth error: $e");
      await ensureAuthenticated();
    }
  }

  /// Ensures the user is authenticated with Firebase (anonymously if needed)
  Future<void> ensureAuthenticated() async {
    if (_auth.currentUser == null) {
      try {
        print("Fallback: Signing in anonymously...");
        await _auth.signInAnonymously();
        print("Authenticated anonymously (UID: ${_auth.currentUser?.uid})");
      } catch (e) {
        print("Error during anonymous authentication: $e");
      }
    }
  }

  // Option 2: Restricted list of allowed users
  final List<String> allowedUsernames = ['khentsgdz', 'clairjassen'];

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
