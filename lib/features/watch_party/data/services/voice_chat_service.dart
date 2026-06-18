import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:web/web.dart' as web;

enum VoiceChatState { idle, calling, connected, ended }

/// One persistent in-app notification. Emitted by
/// [VoiceChatService.watchIncoming] when the partner has started
/// a watch party on the other side and this device is the callee.
/// Cleared (replaced with `null`) when the user opens the watch
/// party screen, when the partner ends the call, or when the room
/// doc disappears.
class IncomingCall {
  final String roomId;
  final String callerUid;
  final String callerName;
  final String mediaTitle;
  final String mediaPosterPath;
  final String mediaType;
  final int? season;
  final int? episode;
  final DateTime seenAt;

  const IncomingCall({
    required this.roomId,
    required this.callerUid,
    required this.callerName,
    required this.mediaTitle,
    required this.mediaPosterPath,
    required this.mediaType,
    required this.season,
    required this.episode,
    required this.seenAt,
  });
}

/// WebRTC voice chat for the Watch Party screen, plus a side
/// channel that surfaces "the partner started a watch party"
/// events to the rest of the app (so the silent banner can show
/// even when the user isn't on the watch party screen).
///
/// Signalling uses a Firestore document at
/// `voice_rooms/{roomId}` (the same roomId the host uses for the
/// watch party room — sorted joined uids). The doc carries the
/// SDP offer/answer; the `candidates` subcollection carries
/// trickle ICE candidates. Both sides subscribe to the doc and
/// react to state changes.
///
/// Lifecycle states:
///   * `idle` — no peer connection, no room listening.
///   * `calling` — the call is being set up (offer written, no
///     answer yet, or the peer connection is still negotiating).
///   * `connected` — `RTCPeerConnectionState` reached `connected`.
///   * `ended` — either side ended the call, or the connection
///     dropped past one ICE-restart attempt.
class VoiceChatService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  RTCPeerConnection? _pc;
  MediaStream? _localStream;
  StreamSubscription<DocumentSnapshot>? _signalSub;
  StreamSubscription<QuerySnapshot>? _candidateSub;
  StreamSubscription<DocumentSnapshot>? _incomingSignalSub;

  /// Hook for the host's beforeunload cleanup. Held so dispose()
  /// can detach it cleanly. Web only.
  web.EventListener? _beforeUnloadListener;

  final ValueNotifier<VoiceChatState> state =
      ValueNotifier(VoiceChatState.idle);
  final ValueNotifier<bool> isMuted = ValueNotifier(false);
  final ValueNotifier<bool> hasRemoteAudio = ValueNotifier(false);

  String? _roomId;
  String? _myUid;
  String? _remoteUid;
  bool _remoteDescSet = false;
  bool _iceRestarted = false;

  /// Stream controller for app-wide "incoming call" notifications.
  /// We expose a single global stream — if multiple instances
  /// exist, the last one wins. The banner widget subscribes to
  /// this stream and shows the silent top-of-screen card.
  static final StreamController<IncomingCall?> _incomingController =
      StreamController<IncomingCall?>.broadcast();
  static Stream<IncomingCall?> get incomingStream => _incomingController.stream;

  /// Latest incoming call, if any. Cached so the banner can read
  /// it on first paint without waiting for the stream to emit.
  static IncomingCall? _latestIncoming;
  static IncomingCall? get latestIncoming => _latestIncoming;

  static const String _collection = 'voice_rooms';

  /// Public Google STUN servers. No TURN — we rely on direct
  /// connectivity between the two clients. This will fail behind
  /// carrier-grade NATs; the design intentionally keeps the
  /// surface area tiny for a private two-user app.
  static const _iceServers = [
    {'urls': 'stun:stun.l.google.com:19302'},
    {'urls': 'stun:stun1.l.google.com:19302'},
    {'urls': 'stun:stun2.l.google.com:19302'},
  ];

  // ─────────────────────────────────────────────────────────────────
  // Call lifecycle
  // ─────────────────────────────────────────────────────────────────

  /// Join (or start) a voice call in [roomId] with [remoteUid] as
  /// the other side. If [isCaller] is true, the offer is created
  /// and written to Firestore; otherwise we wait for the offer to
  /// appear on the doc.
  ///
  /// Pass [callerName] when starting the call so the partner's
  /// incoming banner can display "Khent is calling". Optional
  /// media fields populate the banner subtitle ("watching The Bear").
  Future<void> init({
    required String roomId,
    required String myUid,
    required String remoteUid,
    required bool isCaller,
    String? callerName,
    String? mediaTitle,
    String? mediaPosterPath,
    String? mediaType,
    int? season,
    int? episode,
  }) async {
    _roomId = roomId;
    _myUid = myUid;
    _remoteUid = remoteUid;
    _iceRestarted = false;
    _remoteDescSet = false;
    state.value = VoiceChatState.calling;

    // Web only: install beforeunload so a tab close writes
    // state='ended' instead of leaving the room in 'calling'
    // forever.
    _installBeforeUnload();

    try {
      await _getMedia();
      await _createPC();
      _listenSignal();
      _listenCandidates();

      if (isCaller) {
        await _createOffer(
          callerName: callerName,
          mediaTitle: mediaTitle,
          mediaPosterPath: mediaPosterPath,
          mediaType: mediaType,
          season: season,
          episode: episode,
        );
      }
    } catch (e) {
      debugPrint('VoiceChatService.init failed: $e');
      state.value = VoiceChatState.ended;
    }
  }

  Future<void> _getMedia() async {
    try {
      _localStream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': false,
      });
    } catch (e) {
      debugPrint('VoiceChatService.getUserMedia failed: $e');
      rethrow;
    }
  }

  Future<void> _createPC() async {
    _pc = await createPeerConnection({
      'iceServers': _iceServers,
      'iceTransportPolicy': 'all',
    });

    _pc!.onIceCandidate = (candidate) {
      _sendCandidate(candidate);
    };

    _pc!.onIceConnectionState = (s) {
      debugPrint('VoiceChatService: ICE $s');
    };

    _pc!.onTrack = (event) {
      debugPrint('VoiceChatService: remote track received');
      if (event.track.kind == 'audio') {
        _attachRemoteAudio(event.streams[0]);
      }
    };

    _pc!.onConnectionState = (s) async {
      debugPrint('VoiceChatService: connection $s');
      if (s == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        state.value = VoiceChatState.connected;
        _iceRestarted = false;
      } else if (s == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
        // Don't immediately bail — give ICE a few seconds to
        // self-heal. The "failed" handler below does the heavy
        // lifting.
      } else if (s == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        await _handleConnectionFailed();
      }
    };

    if (_localStream != null) {
      for (final track in _localStream!.getAudioTracks()) {
        await _pc!.addTrack(track, _localStream!);
      }
    }
  }

  /// Called when the peer connection reaches `failed`. We attempt
  /// one ICE restart; if that doesn't recover the link within a
  /// short window we end the call.
  Future<void> _handleConnectionFailed() async {
    if (_pc == null) {
      state.value = VoiceChatState.ended;
      return;
    }
    if (!_iceRestarted) {
      _iceRestarted = true;
      debugPrint('VoiceChatService: ICE failed — attempting restart');
      try {
        final offer = await _pc!.createOffer({
          'iceRestart': true,
          'offerToReceiveAudio': true,
        });
        await _pc!.setLocalDescription(offer);
        final offerJson = jsonEncode(offer.toMap());
        await _db.collection(_collection).doc(_roomId).set({
          'callerUid': _myUid,
          'calleeUid': _remoteUid,
          'state': 'calling',
          'offer': offerJson,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        // Give the new ICE gathering a few seconds to complete.
        // If onConnectionState fires "connected" in that window
        // we recover; if it stays failed, the user will hang up
        // manually or the watch party will end.
        return;
      } catch (e) {
        debugPrint('VoiceChatService: ICE restart failed: $e');
      }
    }
    state.value = VoiceChatState.ended;
    await _markEnded();
  }

  void _attachRemoteAudio(MediaStream stream) {
    _pc!.onAddStream = (stream) {
      hasRemoteAudio.value = true;
    };
  }

  Future<void> _createOffer({
    String? callerName,
    String? mediaTitle,
    String? mediaPosterPath,
    String? mediaType,
    int? season,
    int? episode,
  }) async {
    try {
      final offer = await _pc!.createOffer({'offerToReceiveAudio': true});
      await _pc!.setLocalDescription(offer);
      final offerJson = jsonEncode(offer.toMap());

      await _db.collection(_collection).doc(_roomId).set({
        'callerUid': _myUid,
        'calleeUid': _remoteUid,
        if (callerName != null) 'callerName': callerName,
        'state': 'calling',
        'offer': offerJson,
        'answer': '',
        if (mediaTitle != null) 'mediaTitle': mediaTitle,
        if (mediaPosterPath != null) 'mediaPosterPath': mediaPosterPath,
        if (mediaType != null) 'mediaType': mediaType,
        if (season != null) 'season': season,
        if (episode != null) 'episode': episode,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('VoiceChatService._createOffer failed: $e');
    }
  }

  Future<void> _handleOffer(String offerJson) async {
    try {
      final map = jsonDecode(offerJson) as Map<String, dynamic>;
      final desc = RTCSessionDescription(map['sdp'], map['type']);
      await _pc!.setRemoteDescription(desc);
      _remoteDescSet = true;

      final answer = await _pc!.createAnswer({'offerToReceiveAudio': true});
      await _pc!.setLocalDescription(answer);
      final answerJson = jsonEncode(answer.toMap());

      await _db.collection(_collection).doc(_roomId).update({
        'answer': answerJson,
        'state': 'calling',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('VoiceChatService._handleOffer failed: $e');
    }
  }

  Future<void> _handleAnswer(String answerJson) async {
    try {
      if (_remoteDescSet) return;
      final map = jsonDecode(answerJson) as Map<String, dynamic>;
      final desc = RTCSessionDescription(map['sdp'], map['type']);
      await _pc!.setRemoteDescription(desc);
      _remoteDescSet = true;
    } catch (e) {
      debugPrint('VoiceChatService._handleAnswer failed: $e');
    }
  }

  Future<void> _sendCandidate(RTCIceCandidate candidate) async {
    if (_roomId == null) return;
    try {
      await _db
          .collection(_collection)
          .doc(_roomId)
          .collection('candidates')
          .add({
        'from': _myUid,
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('VoiceChatService._sendCandidate failed: $e');
    }
  }

  void _listenSignal() {
    if (_roomId == null) return;
    _signalSub =
        _db.collection(_collection).doc(_roomId).snapshots().listen((snap) {
      if (!snap.exists) return;
      final data = snap.data()!;

      final docState = data['state'] as String?;
      if (docState == 'ended') {
        state.value = VoiceChatState.ended;
        return;
      }

      final callerUid = data['callerUid'] as String?;

      if (_myUid != callerUid) {
        final offer = data['offer'] as String?;
        final answer = data['answer'] as String?;
        if (offer != null && offer.isNotEmpty && (answer == null || answer.isEmpty)) {
          _handleOffer(offer);
        }
      }

      if (_myUid == callerUid) {
        final answer = data['answer'] as String?;
        if (answer != null && answer.isNotEmpty && !_remoteDescSet) {
          _handleAnswer(answer);
        }
      }
    });
  }

  void _listenCandidates() {
    if (_roomId == null) return;
    _candidateSub = _db
        .collection(_collection)
        .doc(_roomId)
        .collection('candidates')
        .snapshots()
        .listen((snap) {
      for (final change in snap.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data()!;
          if (data['from'] == _myUid) continue;
          if (data['candidate'] == null || data['sdpMid'] == null) continue;
          try {
            _pc?.addCandidate(RTCIceCandidate(
              data['candidate'] as String,
              data['sdpMid'] as String,
              (data['sdpMLineIndex'] as num?)?.toInt() ?? 0,
            ));
          } catch (e) {
            // Candidate may have been added before remote desc — browser queues it
          }
        }
      }
    });
  }

  Future<void> toggleMute() async {
    if (_localStream == null) return;
    final muted = !isMuted.value;
    for (final track in _localStream!.getAudioTracks()) {
      track.enabled = !muted;
    }
    isMuted.value = muted;
  }

  Future<void> endCall() async {
    await _markEnded();
    await dispose();
  }

  Future<void> _markEnded() async {
    if (_roomId == null) return;
    try {
      await _db.collection(_collection).doc(_roomId).update({
        'state': 'ended',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('VoiceChatService._markEnded failed: $e');
    }
  }

  /// Clean up the peer connection, the local media stream, and
  /// every subscription. Resets state so the service can be
  /// re-initialised for the next call. Idempotent.
  Future<void> dispose() async {
    _signalSub?.cancel();
    _candidateSub?.cancel();
    _incomingSignalSub?.cancel();
    _signalSub = null;
    _candidateSub = null;
    _incomingSignalSub = null;
    _uninstallBeforeUnload();
    if (_pc != null) {
      try {
        await _pc!.close();
      } catch (_) {}
      _pc = null;
    }
    if (_localStream != null) {
      for (final track in _localStream!.getAudioTracks()) {
        try {
          track.stop();
        } catch (_) {}
      }
      _localStream = null;
    }
    _remoteDescSet = false;
    _iceRestarted = false;
    state.value = VoiceChatState.idle;
    isMuted.value = false;
    hasRemoteAudio.value = false;
  }

  // ─────────────────────────────────────────────────────────────────
  // App-wide "incoming call" listener
  // ─────────────────────────────────────────────────────────────────
  //
  // Watches the same voice_rooms/{roomId} doc that the WebRTC
  // signalling uses, but on the *callee* side. When the doc
  // appears with state='calling' and our uid is the callee, emit
  // an IncomingCall to the global stream so the silent banner
  // widget can show it. Cleared when the user opens the watch
  // party screen, the room ends, or the doc disappears.

  /// Begin watching for an incoming watch party call. Idempotent —
  /// calling it twice from different places just replaces the
  /// listener with one bound to the new ids. Pass null to stop
  /// watching (the banner should call this when the user is on
  /// the watch party screen, so the in-app notification doesn't
  /// fight the active call UI).
  static void watchIncoming({
    required String myUid,
    required String? partnerUid,
  }) {
    // No partner (cinema-only profile) — nothing to listen for.
    if (partnerUid == null || partnerUid.isEmpty) {
      _clearIncoming();
      return;
    }
    final sorted = [myUid, partnerUid]..sort();
    final roomId = '${sorted[0]}_${sorted[1]}';

    // Cancel any previous watcher before installing a new one.
    _incomingWatcherSub?.cancel();
    _incomingWatcherSub = _incomingDb
        .collection(_collection)
        .doc(roomId)
        .snapshots()
        .listen((snap) {
      if (!snap.exists) {
        _clearIncoming();
        return;
      }
      final data = snap.data()!;
      final state = data['state'] as String?;
      final callerUid = data['callerUid'] as String?;
      final calleeUid = data['calleeUid'] as String?;

      // We only surface the banner on the callee's side, and only
      // while the call is in a non-terminal state. "connected"
      // and "ended" should not show a "tap to join" banner.
      if (callerUid == myUid) {
        // We're the caller — we don't need our own banner.
        _clearIncoming();
        return;
      }
      if (calleeUid != myUid) {
        _clearIncoming();
        return;
      }
      if (state == 'ended' || state == 'connected') {
        _clearIncoming();
        return;
      }

      // surface the latest media metadata
      final incoming = IncomingCall(
        roomId: roomId,
        callerUid: callerUid ?? '',
        callerName: (data['callerName'] as String?) ?? 'Partner',
        mediaTitle: (data['mediaTitle'] as String?) ?? '',
        mediaPosterPath: (data['mediaPosterPath'] as String?) ?? '',
        mediaType: (data['mediaType'] as String?) ?? 'movie',
        season: (data['season'] is num) ? (data['season'] as num).toInt() : null,
        episode: (data['episode'] is num) ? (data['episode'] as num).toInt() : null,
        seenAt: DateTime.now(),
      );
      _latestIncoming = incoming;
      if (!_incomingController.isClosed) {
        _incomingController.add(incoming);
      }
    });
  }

  /// Stop watching. Called from the watch party screen on entry
  /// (so we don't double-notify) and on logout.
  static void clearIncomingWatcher() {
    _incomingWatcherSub?.cancel();
    _incomingWatcherSub = null;
  }

  static void _clearIncoming() {
    if (_latestIncoming == null && !_incomingController.hasListener) return;
    _latestIncoming = null;
    if (!_incomingController.isClosed) {
      _incomingController.add(null);
    }
  }

  static final FirebaseFirestore _incomingDb = FirebaseFirestore.instance;
  static StreamSubscription<DocumentSnapshot>? _incomingWatcherSub;

  // ─────────────────────────────────────────────────────────────────
  // Web tab-close cleanup
  // ─────────────────────────────────────────────────────────────────

  void _installBeforeUnload() {
    if (!kIsWeb) return;
    _uninstallBeforeUnload();
    final listener = ((web.Event _) {
      // Best-effort write. We can't await inside the listener.
      if (_roomId != null && state.value != VoiceChatState.ended) {
        _db.collection(_collection).doc(_roomId).update({
          'state': 'ended',
          'updatedAt': FieldValue.serverTimestamp(),
        }).catchError((Object e) {
          debugPrint('VoiceChatService beforeunload update failed: $e');
        });
      }
      // Also stop local tracks so the browser releases the mic.
      if (_localStream != null) {
        for (final track in _localStream!.getAudioTracks()) {
          try {
            track.stop();
          } catch (_) {}
        }
      }
    }).toJS;
    web.window.addEventListener('beforeunload', listener);
    _beforeUnloadListener = listener;
  }

  void _uninstallBeforeUnload() {
    if (!kIsWeb) return;
    if (_beforeUnloadListener == null) return;
    try {
      web.window.removeEventListener('beforeunload', _beforeUnloadListener);
    } catch (_) {}
    _beforeUnloadListener = null;
  }
}
