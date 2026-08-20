import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/config/env_config.dart';
import '../../../../core/utils/logger.dart';

/// Handles Spotify OAuth (Authorization Code + PKCE) for Everglow Duo.
///
/// Each Firebase user links their own Spotify account. Tokens are stored
/// server-side in `spotify_tokens/{uid}` written by Cloud Functions, but
/// this service reads the link status for UI.
///
/// Scopes needed for Web Playback + reading currently playing.
class SpotifyAuthService extends ChangeNotifier {
  static const _verifierKey = 'spotify_code_verifier';
  static const _scopes = [
    'streaming',
    'user-read-email',
    'user-read-private',
    'user-read-playback-state',
    'user-modify-playback-state',
    'user-read-currently-playing',
  ];

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _linked = false;
  String? _spotifyUserId;
  String? _displayName;
  StreamSubscription? _sub;

  bool get isLinked => _linked;
  String? get spotifyUserId => _spotifyUserId;
  String? get displayName => _displayName;

  String get _functionBase {
    const host = String.fromEnvironment('FUNCTIONS_HOST', defaultValue: '');
    if (host.isNotEmpty) return host;
    return 'https://us-central1-everglow-1c6db.cloudfunctions.net';
  }

  String _redirectUriForCurrentOrigin() {
    // On web, the redirect must match the Spotify Dashboard allowlist.
    // For prod: https://everglow-1c6db.web.app/spotify/callback
    // For local: http://localhost:5000/spotify/callback
    if (kIsWeb) {
      final origin = Uri.base.origin; // e.g. https://everglow-1c6db.web.app
      // If running on web, use that origin
      if (origin.contains('localhost') || origin.contains('127.0.0.1')) {
        return '$origin/spotify/callback';
      }
      // Prod hosts are everglow-1c6db.web.app + everglow-1c6db.firebaseapp.com
      return '$origin/spotify/callback';
    }
    // Fallback
    return 'https://everglow-1c6db.web.app/spotify/callback';
  }

  StreamSubscription? _authSub;

  /// Starts listening to link status for current Firebase user.
  void start() {
    _authSub?.cancel();
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      _sub?.cancel();
      if (user == null) {
        _linked = false;
        _spotifyUserId = null;
        _displayName = null;
        notifyListeners();
        return;
      }
      _sub = _firestore.collection('spotify_tokens').doc(user.uid).snapshots().listen((doc) {
        final data = doc.data();
        final was = _linked;
        final wasId = _spotifyUserId;
        _linked = doc.exists && data != null && (data['access_token'] != null);
        _spotifyUserId = data?['spotify_user_id'] as String?;
        _displayName = data?['spotify_display_name'] as String?;
        if (was != _linked || wasId != _spotifyUserId) notifyListeners();
      }, onError: (_) {});
    });
    // Also kick immediately for already-authed case
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null && _sub == null) {
      _sub = _firestore.collection('spotify_tokens').doc(uid).snapshots().listen((doc) {
        final data = doc.data();
        _linked = doc.exists && data != null && (data['access_token'] != null);
        _spotifyUserId = data?['spotify_user_id'] as String?;
        _displayName = data?['spotify_display_name'] as String?;
        notifyListeners();
      }, onError: (_) {});
    }
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
    _authSub?.cancel();
    _authSub = null;
  }

  String _generateVerifier() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';
    final rnd = Random.secure();
    return List.generate(64, (_) => chars[rnd.nextInt(chars.length)]).join();
  }

  String _challengeFor(String verifier) {
    final digest = sha256.convert(utf8.encode(verifier));
    return base64UrlEncode(digest.bytes).replaceAll('=', '');
  }

  /// Step 1: Redirect to Spotify authorize. Call from UI button.
  Future<void> linkSpotify() async {
    final clientId = EnvConfig.spotifyClientId;
    if (clientId.isEmpty) {
      Logger.w('SpotifyAuth: SPOTIFY_CLIENT_ID missing - set in assets/env.txt and rebuild');
      throw Exception('Spotify not configured (missing client ID)');
    }
    final verifier = _generateVerifier();
    final challenge = _challengeFor(verifier);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_verifierKey, verifier);

    final redirectUri = _redirectUriForCurrentOrigin();
    final uri = Uri.https('accounts.spotify.com', '/authorize', {
      'client_id': clientId,
      'response_type': 'code',
      'redirect_uri': redirectUri,
      'scope': _scopes.join(' '),
      'code_challenge_method': 'S256',
      'code_challenge': challenge,
      'show_dialog': 'false',
    });
    Logger.d('SpotifyAuth authorize -> $uri');
    // On web, externalApplication uses window.open which can be blocked.
    // Try externalApplication first, then platformDefault, then give a
    // helpful error that the UI can surface in a SnackBar.
    var opened = false;
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      Logger.w('launchUrl externalApplication failed: $e');
    }
    if (!opened) {
      try {
        opened = await launchUrl(uri, mode: LaunchMode.platformDefault);
      } catch (e) {
        Logger.w('launchUrl platformDefault failed: $e');
      }
    }
    if (!opened) {
      throw Exception(
        'Could not open Spotify auth — pop-up blocked? Allow pop-ups for ${Uri.base.origin} and try again, or open manually: $uri',
      );
    }
  }

  /// Step 2: Called on `/spotify/callback?code=...` to exchange code.
  Future<bool> handleCallback(String code) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final verifier = prefs.getString(_verifierKey);
      final redirectUri = _redirectUriForCurrentOrigin();
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      if (token == null) throw Exception('Not authenticated');
      // Try Cloud Function base then hosting rewrite
      final payload = <String, dynamic>{'code': code, 'redirectUri': redirectUri};
      if (verifier != null) payload['codeVerifier'] = verifier;
      final body = jsonEncode(payload);
      http.Response res;
      try {
        res = await http
            .post(Uri.parse('$_functionBase/spotifyExchange'),
                headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'}, body: body)
            .timeout(const Duration(seconds: 12));
        if (res.statusCode == 404) throw Exception('404');
      } catch (_) {
        res = await http
            .post(Uri.parse('/api/spotifyExchange'),
                headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'}, body: body)
            .timeout(const Duration(seconds: 12));
      }
      if (res.statusCode != 200) {
        Logger.e('spotifyExchange failed ${res.statusCode}: ${res.body}');
        return false;
      }
      await prefs.remove(_verifierKey);
      Logger.d('Spotify linked');
      notifyListeners();
      return true;
    } catch (e) {
      Logger.e('spotifyExchange error', error: e);
      return false;
    }
  }

  Future<void> unlink() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await _firestore.collection('spotify_tokens').doc(uid).delete();
    _linked = false;
    _spotifyUserId = null;
    notifyListeners();
  }

  /// Reads stored access_token (client-side cache) - prefer server proxy for now.
  Future<String?> getStoredAccessToken() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    final doc = await _firestore.collection('spotify_tokens').doc(uid).get();
    return doc.data()?['access_token'] as String?;
  }

  /// Proxies currently-playing via Cloud Function (keeps token server-side).
  Future<Map<String, dynamic>?> fetchCurrentlyPlaying() async {
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      if (token == null) return null;
      http.Response res;
      try {
        res = await http.get(Uri.parse('$_functionBase/spotifyCurrentlyPlaying'), headers: {'Authorization': 'Bearer $token'}).timeout(const Duration(seconds: 10));
        if (res.statusCode == 404) throw Exception('404');
      } catch (_) {
        res = await http.get(Uri.parse('/api/spotifyCurrentlyPlaying'), headers: {'Authorization': 'Bearer $token'}).timeout(const Duration(seconds: 10));
      }
      if (res.statusCode != 200) return null;
      return json.decode(res.body) as Map<String, dynamic>;
    } catch (e) {
      Logger.w('fetchCurrentlyPlaying error: $e');
      return null;
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _authSub?.cancel();
    super.dispose();
  }
}
