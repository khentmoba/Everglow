import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/dashboard/data/services/letterbox_service.dart';
import '../../features/xp/data/services/xp_service.dart';
import '../config/env_config.dart';
import '../utils/logger.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? _user;
  String? _currentUser;
  String? _partnerUid;
  String? _partnerNameResolved;
  bool _hasSyncedUserDoc = false;
  bool _isResolvingPartner = false;
  String? _lastAuthError;

  AuthService() {
    _loadSession();
    _auth.authStateChanges().listen((User? user) {
      _user = user;
      _hasSyncedUserDoc = false;
      if (user == null) {
        _partnerUid = null;
        _partnerNameResolved = null;
        _isResolvingPartner = false;
      } else if (_currentUser != null) {
        // Anonymous sessions can never satisfy firestore.rules
        // (`isNotAnonymous` is required for every app read), so an
        // anonymous user paired with a couple username would only ever
        // see permission-denied streams and false-empty shelves. Drop the
        // false session so the gateway forces a real login instead.
        if (user.isAnonymous && isCoupleUser) {
          // ignore: avoid_print
          print(
            '[AuthService] clearing anonymous session for couple user $_currentUser — real login required',
          );
          unawaited(_auth.signOut());
        } else {
          unawaited(_syncUserDoc());
        }
      }
      notifyListeners();
    });
  }

  Future<void> _loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    _currentUser = prefs.getString('current_user_name');
    if (_currentUser != null) {
      Logger.i("Restored session for: $_currentUser");
      // Same heal as the auth-state listener: a persisted anonymous user
      // with a couple username can never read couple data. Sign out so the
      // gateway asks for a real login instead of showing empty shelves.
      if (isCoupleUser && _auth.currentUser?.isAnonymous == true) {
        // ignore: avoid_print
        print(
          '[AuthService] clearing persisted anonymous session for $_currentUser — real login required',
        );
        try {
          await _auth.signOut();
        } catch (e) {
          Logger.e('Failed to clear anonymous session', error: e);
        }
        _user = null;
      }
      notifyListeners();
      // If auth state already fired before we loaded the session,
      // sync the user doc now that _currentUser is available.
      if (_auth.currentUser != null && !_hasSyncedUserDoc) {
        unawaited(_syncUserDoc());
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

  /// True when the Firebase session is anonymous. Anonymous sessions are
  /// blocked by firestore.rules on every app read, so one paired with a
  /// couple username can only ever produce permission-denied streams.
  bool get isAnonymousSession => _auth.currentUser?.isAnonymous == true;

  /// Single-line auth diagnosis for the browser console. The dashboard
  /// logs this on load so a permission-denied report always carries the
  /// session facts needed to tell a guest session from a missing user doc.
  String get diagLine =>
      'uid=${_auth.currentUser?.uid ?? 'none'} '
      'anonymous=$isAnonymousSession '
      'username=${_currentUser ?? 'none'} '
      'usersDocSynced=$_hasSyncedUserDoc';

  /// True once both Firebase Auth and SharedPreferences have resolved.
  /// Dashboard and partner-dependent features should wait for this.
  bool get isReady => _user != null && _currentUser != null;

  /// Dynamically resolved partner UID from the /users collection.
  /// Populated after login via [_syncUserDoc].
  String? get partnerUid => _partnerUid;

  /// True while partner UID resolution is in flight. Presence widgets use
  /// this to show a linking state instead of the unavailable fallback.
  bool get isResolvingPartner => _isResolvingPartner;

  /// Re-runs partner UID resolution on demand. Safe to call repeatedly and
  /// from any screen: concurrent calls are ignored and transient failures
  /// preserve the last known [partnerUid] instead of clearing it.
  /// Screens that depend on the partner link (Sanctuary, watch party) should
  /// call this after ensuring the user doc so a single failed background
  /// resolve no longer sticks until the next full re-login.
  Future<void> refreshPartnerLink() => _resolvePartnerInfo();

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

    if (username == 'clairjassen' || username == 'khentsgdz') {
      throw StateError('Couple access must use server passcode verification');
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
      unawaited(_syncUserDoc());
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
          unawaited(_syncUserDoc());
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

  /// Sets a user-facing auth error without exposing underlying exceptions.
  void setAuthError(String message) {
    _lastAuthError = message;
  }

  /// Writes/updates the /users/{uid} document and resolves the partner's UID
  /// dynamically from Firestore. This replaces the old hard-coded UID system
  /// and is resilient to account recreations.
  ///
  /// The core `users/{uid}` write is awaited, but partner resolution, XP init
  /// and letterbox seeding run in the background so `isReady` flips true
  /// without waiting for 2-3 extra round-trips (≈700ms saved per login).
  Future<void> _syncUserDoc() async {
    final myUid = _auth.currentUser?.uid;
    if (myUid == null || _currentUser == null) return;
    if (_hasSyncedUserDoc) return;
    _hasSyncedUserDoc = true;

    try {
      final db = FirebaseFirestore.instance;

      await db.collection('users').doc(myUid).set({
        'username': _currentUser,
        'partnerUsername': partnerUsername,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      // ignore: avoid_print
      print('[AuthService] users doc synced for $_currentUser ($myUid)');

      // Remaining work doesn't block first paint — fire-and-forget.
      unawaited(
        Future.wait([
          _resolvePartnerInfo().catchError((Object e) {
            Logger.e('AuthService._resolvePartnerInfo failed (bg)', error: e);
          }),
          XPService().initializeProgress(myUid).catchError((Object e) {
            Logger.e('XP init failed (bg)', error: e);
          }),
          if (isCoupleUser)
            LetterboxService().ensureSeeded().catchError((Object e) {
              Logger.e('Letterbox seed failed (bg)', error: e);
            }),
        ]),
      );
    } catch (e) {
      _hasSyncedUserDoc = false;
      // ignore: avoid_print
      print('[AuthService] _syncUserDoc failed for $_currentUser ($myUid): $e');
    }
  }

  /// Queries /users to find the partner's UID by username. If the partner's
  /// account was recreated, this automatically finds their new UID.
  ///
  /// Transient failures (offline, permission-denied before the own user doc
  /// is visible) preserve the last known [_partnerUid] so presence widgets
  /// keep working instead of flipping to the unavailable state. Only a
  /// definitive answer (no partner for this profile, or a successful query
  /// with zero matches) clears the link. Retry at any time via
  /// [refreshPartnerLink].
  Future<void> _resolvePartnerInfo() async {
    if (_isResolvingPartner) return;
    if (_currentUser == null || _auth.currentUser == null) return;
    _isResolvingPartner = true;
    notifyListeners();

    try {
      var partnerUser = partnerUsername;
      try {
        final ownDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(_auth.currentUser!.uid)
            .get();
        final storedPartner = ownDoc.data()?['partnerUsername'] as String?;
        if (storedPartner != null && storedPartner.isNotEmpty) {
          partnerUser = storedPartner;
        }
      } catch (e) {
        Logger.e("AuthService._resolvePartnerInfo own doc read failed", error: e);
      }

      // Cinema-only profiles have no partner; clear decisively.
      if (partnerUser == null) {
        _partnerUid = null;
        _partnerNameResolved = null;
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
          // Partner has never synced a /users doc on this project yet.
          _partnerUid = null;
          _partnerNameResolved = null;
        }
      } catch (e) {
        Logger.e("AuthService._resolvePartnerInfo failed", error: e);
        // Keep the last known UID so a transient error does not stick the
        // UI in the unavailable state; the next refresh will correct it.
      }
    } finally {
      _isResolvingPartner = false;
      notifyListeners();
    }
  }

  /// Server-verified Khent/Clair passcode -> Firebase custom token.
  /// Returns username (khentsgdz/clairjassen) on success, null on bad code.
  Future<String?> verifyCouplePasscode(String passcode) async {
    // Try hosting rewrite first (same-origin, no CORS), then direct CF URL.
    final urls = <Uri>[
      if (kIsWeb) Uri.parse('/api/verifyPasscode'),
      Uri.parse(
        'https://us-central1-everglow-1c6db.cloudfunctions.net/verifyPasscode',
      ),
      Uri.parse('https://everglow-1c6db.web.app/api/verifyPasscode'),
    ];
    for (final url in urls) {
      try {
        final resp = await http
            .post(
              url,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'passcode': passcode}),
            )
            .timeout(const Duration(seconds: 10));
        if (resp.statusCode == 401 || resp.statusCode == 400) {
          return null;
        }
        if (resp.statusCode != 200) {
          Logger.e('verifyCouplePasscode $url -> ${resp.statusCode}: ${resp.body}');
          continue;
        }
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final token = data['token'] as String?;
        final username = data['username'] as String?;
        if (token == null || token.isEmpty || username == null) {
          Logger.e('verifyCouplePasscode missing token/username from $url');
          continue;
        }
        await _auth.signInWithCustomToken(token);
        _currentUser = username;
        await _saveSession(username);
        unawaited(_syncUserDoc());
        _lastAuthError = null;
        notifyListeners();
        return username;
      } catch (e) {
        Logger.e('verifyCouplePasscode $url failed', error: e);
      }
    }
    return null;
  }

  /// Offline fallback for Khent/Clair when verifyPasscode is unreachable.
  ///
  /// Anonymous Firebase sessions are blocked by firestore.rules
  /// (`isNotAnonymous` is required for every app read), so signing in
  /// anonymously would only produce permission-denied streams and
  /// false-empty shelves. Refuse instead with a visible error so the
  /// gateway stays put and the user retries online. Server verification
  /// will sign in the real account on the next online login.
  Future<void> loginCoupleOffline(String username) async {
    if (username != 'khentsgdz' && username != 'clairjassen') return;
    _lastAuthError =
        'Login server unreachable. Please connect to the internet and try again.';
    Logger.e(
      'loginCoupleOffline refused anonymous couple session for $username — real login required',
    );
    notifyListeners();
  }

  /// Direct login for Breyan/Octagram (client-verified, non-sensitive).
  Future<bool> loginCinemaWithPasscode(String passcode) async {
    if (passcode == EnvConfig.breyanPasscode || passcode == '9132') {
      await loginWithPasscode('breyan');
      return lastAuthError == null;
    }
    if (passcode == EnvConfig.octagramPasscode || passcode == '8080') {
      await loginWithPasscode('octagram');
      return lastAuthError == null;
    }
    return false;
  }

  Future<void> logout() async {
    await _auth.signOut();
    _currentUser = null;
    _partnerUid = null;
    _partnerNameResolved = null;
    _isResolvingPartner = false;
    _hasSyncedUserDoc = false;
    await _saveSession(null);
    notifyListeners();
  }
}
