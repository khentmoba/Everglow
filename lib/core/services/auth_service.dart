import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/env_config.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../features/xp/data/services/xp_service.dart';
import '../../features/dashboard/data/services/letterbox_service.dart';
import '../utils/logger.dart';

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

  /// Ensures the user is authenticated with a real account based on their passcode
  Future<void> loginWithPasscode(String username) async {
    String email;
    String password;

    if (username == 'clairjassen') {
      email = EnvConfig.clairEmail;
      password = EnvConfig.clairPassword;
    } else if (username == 'khentsgdz') {
      email = EnvConfig.khentEmail;
      password = EnvConfig.khentPassword;
    } else if (username == 'breyan') {
      email = EnvConfig.breyanEmail;
      password = EnvConfig.breyanPassword;
    } else if (username == 'octagram') {
      email = EnvConfig.octagramEmail;
      password = EnvConfig.octagramPassword;
    } else {
      throw StateError('Unknown username: $username');
    }

    if (email.isEmpty || password.isEmpty) {
      _lastAuthError =
          '$username credentials are not configured for this build.';
      Logger.e(_lastAuthError!);
      return;
    }

    try {
      Logger.d("Attempting login for $username ($email)...");
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      _currentUser = username;
      await _saveSession(username);
      await _syncUserDoc();
      _lastAuthError = null;
      Logger.i(
        "Successfully logged in as $username (UID: ${_auth.currentUser?.uid})",
      );
      notifyListeners();
    } on FirebaseAuthException catch (e) {
      Logger.e('Login failed with FirebaseAuthException', error: e);
      if (e.code == 'user-not-found' ||
          e.code == 'invalid-credential' ||
          e.code == 'invalid-email') {
        try {
          await _auth.createUserWithEmailAndPassword(
            email: email,
            password: password,
          );
          _currentUser = username;
          await _saveSession(username);
          await _syncUserDoc();
          _lastAuthError = null;
          Logger.i(
            "Successfully registered and logged in as new user: $username (UID: ${_auth.currentUser?.uid})",
          );
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
      // Anonymous sessions are blocked by firestore.rules, so silently
      // creating one would only produce a broken "guest" experience.
      Logger.e(
        'Authentication required; anonymous fallback is disabled by security rules.',
      );
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
        'partnerUsername': partnerUsername,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Resolve partner dynamically
      await _resolvePartnerInfo();

      // Initialize XP progress doc (no-op if already exists)
      await XPService().initializeProgress(myUid);

      // Seed a sample letterbox note if the collection is empty
      await LetterboxService().ensureSeeded();

      _hasSyncedUserDoc = true;
    } catch (e) {
      Logger.e("AuthService._syncUserDoc failed", error: e);
    }
  }

  /// Queries /users to find the partner's UID by username. If the partner's
  /// account was recreated, this automatically finds their new UID.
  Future<void> _resolvePartnerInfo() async {
    var partnerUser = partnerUsername;
    try {
      final ownDoc = _auth.currentUser != null
          ? await FirebaseFirestore.instance
              .collection('users')
              .doc(_auth.currentUser!.uid)
              .get()
          : null;
      final storedPartner = ownDoc?.data()?['partnerUsername'] as String?;
      if (storedPartner != null && storedPartner.isNotEmpty) {
        partnerUser = storedPartner;
      }
    } catch (e) {
      Logger.e("AuthService._resolvePartnerInfo own doc read failed", error: e);
    }

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
        _partnerNameResolved = partnerUser == 'khentsgdz' ? 'Khent' : 'Clair';
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

  /// Server-verified Khent/Clair passcode -> Firebase custom token.
  /// Returns username (khentsgdz/clairjassen) on success, null on bad code.
  Future<String?> verifyCouplePasscode(String passcode) async {
    try {
      final resp = await http.post(Uri.parse('https://us-central1-everglow-1c6db.cloudfunctions.net/verifyPasscode'), headers: {'Content-Type': 'application/json'}, body: jsonEncode({'passcode': passcode})).timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200) return null;
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final token = data['token'] as String?;
      final username = data['username'] as String?;
      if (token == null || token.isEmpty || username == null) return null;
      await _auth.signInWithCustomToken(token);
      _currentUser = username;
      await _saveSession(username);
      await _syncUserDoc();
      _lastAuthError = null;
      notifyListeners();
      return username;
    } catch (e) { Logger.e('verifyCouplePasscode failed', error: e); return null; }
  }

  /// Direct login for Breyan/Octagram (client-verified, non-sensitive).
  Future<bool> loginCinemaWithPasscode(String passcode) async {
    if (passcode == EnvConfig.breyanPasscode) { await loginWithPasscode('breyan'); return lastAuthError == null; }
    if (passcode == EnvConfig.octagramPasscode) { await loginWithPasscode('octagram'); return lastAuthError == null; }
    return false;
  }

  Future<void> logout() async {
    await _auth.signOut();
    _currentUser = null;
    await _saveSession(null);
    notifyListeners();
  }
}
