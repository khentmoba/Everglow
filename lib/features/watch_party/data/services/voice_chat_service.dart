import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/utils/logger.dart';
import '../../../../core/utils/firestore_stream_utils.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:web/web.dart' as web;

import '../models/watch_party_room.dart';
import 'incoming_call_validator.dart';

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
  final int? tmdbId;
  final int? malId;
  final bool isAnime;
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
    this.tmdbId,
    this.malId,
    this.isAnime = false,
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
    int? tmdbId,
    int? malId,
    bool? isAnime,
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
          tmdbId: tmdbId,
          malId: malId,
          isAnime: isAnime ?? false,
          season: season,
          episode: episode,
        );
      }
    } catch (e) {
      Logger.e('VoiceChatService.init failed', error: e);
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
      Logger.e('VoiceChatService.getUserMedia failed', error: e);
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
      Logger.d('VoiceChatService: ICE $s');
    };

    _pc!.onTrack = (event) {
      Logger.d('VoiceChatService: remote track received');
      if (event.track.kind == 'audio') {
        _attachRemoteAudio(event.streams[0]);
      }
    };

    _pc!.onConnectionState = (s) async {
      Logger.d('VoiceChatService: connection $s');
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
      Logger.w('VoiceChatService: ICE failed — attempting restart');
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
          'answer': '',  // clear old answer so callee processes the restart offer
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        // Give the new ICE gathering a few seconds to complete.
        // If onConnectionState fires "connected" in that window
        // we recover; if it stays failed, the user will hang up
        // manually or the watch party will end.
        return;
      } catch (e) {
        Logger.e('VoiceChatService: ICE restart failed', error: e);
      }
    }
    state.value = VoiceChatState.ended;
    await _markEnded();
  }

  void _attachRemoteAudio(MediaStream stream) {
    hasRemoteAudio.value = true;
  }

  Future<void> _createOffer({
    String? callerName,
    String? mediaTitle,
    String? mediaPosterPath,
    String? mediaType,
    int? tmdbId,
    int? malId,
    bool isAnime = false,
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
        'callerName': ?callerName,
        'state': 'calling',
        'offer': offerJson,
        'answer': '',
        'mediaTitle': ?mediaTitle,
        'mediaPosterPath': ?mediaPosterPath,
        'mediaType': ?mediaType,
        'tmdbId': ?tmdbId,
        'malId': ?malId,
        'isAnime': isAnime,
        'season': ?season,
        'episode': ?episode,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      Logger.e('VoiceChatService._createOffer failed', error: e);
    }
  }

  Future<void> _handleOffer(String offerJson) async {
    try {
      // Reset flag so a new offer (ICE restart) can set the remote
      // description again.
      _remoteDescSet = false;

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
      Logger.e('VoiceChatService._handleOffer failed', error: e);
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
      Logger.e('VoiceChatService._handleAnswer failed', error: e);
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
      Logger.e('VoiceChatService._sendCandidate failed', error: e);
    }
  }

  void _listenSignal() {
    if (_roomId == null) return;
    _signalSub = withFirestoreTimeout(
        _db.collection(_collection).doc(_roomId).snapshots(),
        label: 'voice_chat_room_state',
      ).listen((snap) {
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
    _candidateSub = withFirestoreTimeout(
        _db
            .collection(_collection)
            .doc(_roomId)
            .collection('candidates')
            .snapshots(),
        label: 'voice_chat_candidates',
      ).listen((snap) {
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
      Logger.e('VoiceChatService._markEnded failed', error: e);
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
      } catch (e) {
        debugPrint('[VoiceChatService] Failed to close peer connection: $e');
      }
      _pc = null;
    }
    if (_localStream != null) {
      for (final track in _localStream!.getAudioTracks()) {
        try {
          track.stop();
        } catch (e) {
          debugPrint('[VoiceChatService] Failed to stop audio track: $e');
        }
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

    // Drop any cached invitation from a previous session until the
    // fresh snapshots confirm the party is still live.
    _clearIncoming();
    _incomingVoiceSnapshot = null;
    _incomingPartySnapshot = null;

    // Cancel any previous watchers before installing new ones.
    _incomingWatcherSub?.cancel();
    _incomingPartySub?.cancel();

    _incomingWatcherSub = withFirestoreTimeout(
        _incomingDb
            .collection(_collection)
            .doc(roomId)
            .snapshots(),
        label: 'voice_chat_incoming',
      ).listen((snap) {
      _incomingVoiceSnapshot = snap.exists ? snap : null;
      _evaluateIncoming(myUid: myUid, roomId: roomId);
    });

    // The voice room is only meaningful while the matching watch
    // party room is still live. A room left in `calling` by a closed
    // tab or an old session must never re-surface as an invitation.
    _incomingPartySub = withFirestoreTimeout(
        _incomingDb
            .collection(_watchPartyCollection)
            .doc(roomId)
            .snapshots(),
        label: 'watch_party_room_incoming',
      ).listen((snap) {
      _incomingPartySnapshot = snap.exists ? snap : null;
      _evaluateIncoming(myUid: myUid, roomId: roomId);
    });
  }

  static void _evaluateIncoming({
    required String myUid,
    required String roomId,
  }) {
    final snap = _incomingVoiceSnapshot;
    if (snap == null || !snap.exists) {
      _clearIncoming();
      return;
    }
    final data = snap.data();
    if (data == null) {
      _clearIncoming();
      return;
    }

    WatchPartyRoom? partyRoom;
    final partySnap = _incomingPartySnapshot;
    if (partySnap != null && partySnap.exists) {
      try {
        partyRoom = WatchPartyRoom.fromFirestore(partySnap);
      } catch (e) {
        debugPrint(
            'VoiceChatService: failed to parse watch party room $roomId: $e');
      }
    }

    if (!isLiveIncomingCall(
      myUid: myUid,
      voiceData: data,
      partyActive: partyRoom?.active ?? false,
      partyUpdatedAt: partyRoom?.updatedAt,
      now: DateTime.now(),
    )) {
      _clearIncoming();
      return;
    }

    // surface the latest media metadata
    final incoming = IncomingCall(
      roomId: roomId,
      callerUid: (data['callerUid'] as String?) ?? '',
      callerName: (data['callerName'] as String?) ?? 'Partner',
      mediaTitle: (data['mediaTitle'] as String?) ?? '',
      mediaPosterPath: (data['mediaPosterPath'] as String?) ?? '',
      mediaType: (data['mediaType'] as String?) ?? 'movie',
      tmdbId: (data['tmdbId'] is num) ? (data['tmdbId'] as num).toInt() : null,
      malId: (data['malId'] is num) ? (data['malId'] as num).toInt() : null,
      isAnime: data['isAnime'] == true,
      season: (data['season'] is num) ? (data['season'] as num).toInt() : null,
      episode: (data['episode'] is num) ? (data['episode'] as num).toInt() : null,
      seenAt: DateTime.now(),
    );

    final previous = _latestIncoming;
    if (previous != null &&
        previous.roomId == incoming.roomId &&
        previous.callerUid == incoming.callerUid &&
        previous.mediaTitle == incoming.mediaTitle) {
      // The party-room heartbeat refreshes every few seconds; don't
      // churn the banner unless the invitation itself changed.
      return;
    }
    _latestIncoming = incoming;
    if (!_incomingController.isClosed) {
      _incomingController.add(incoming);
    }
  }

  /// Stop watching. Called from the watch party screen on entry
  /// (so we don't double-notify) and on logout.
  static void clearIncomingWatcher() {
    _incomingWatcherSub?.cancel();
    _incomingWatcherSub = null;
    _incomingPartySub?.cancel();
    _incomingPartySub = null;
    _incomingVoiceSnapshot = null;
    _incomingPartySnapshot = null;
    _clearIncoming();
  }

  static void _clearIncoming() {
    if (_latestIncoming == null && !_incomingController.hasListener) return;
    _latestIncoming = null;
    if (!_incomingController.isClosed) {
      _incomingController.add(null);
    }
  }

  static final FirebaseFirestore _incomingDb = FirebaseFirestore.instance;
  static StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
      _incomingWatcherSub;
  static StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
      _incomingPartySub;
  static DocumentSnapshot<Map<String, dynamic>>? _incomingVoiceSnapshot;
  static DocumentSnapshot<Map<String, dynamic>>? _incomingPartySnapshot;
  static const String _watchPartyCollection = 'watch_party_rooms';

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
          Logger.e('VoiceChatService beforeunload update failed', error: e);
        });
      }
      // Also stop local tracks so the browser releases the mic.
      if (_localStream != null) {
        for (final track in _localStream!.getAudioTracks()) {
          try {
            track.stop();
          } catch (e) {
            debugPrint('[VoiceChatService] Failed to stop track before unload: $e');
          }
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
    } catch (e) {
      debugPrint('[VoiceChatService] Failed to remove beforeunload listener: $e');
    }
    _beforeUnloadListener = null;
  }
}
