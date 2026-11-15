import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/utils/logger.dart';
import '../../../../core/utils/firestore_stream_utils.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../models/watch_party_room.dart';
import 'beforeunload_helper.dart';
import 'incoming_call.dart';
import 'incoming_call_validator.dart';

enum VoiceChatState { idle, calling, connected, ended }


class VoiceChatService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  RTCPeerConnection? _pc;
  MediaStream? _localStream;
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  StreamSubscription<DocumentSnapshot>? _signalSub;
  StreamSubscription<QuerySnapshot>? _candidateSub;
  StreamSubscription<DocumentSnapshot>? _incomingSignalSub;

  final BeforeUnloadHelper _beforeUnload = BeforeUnloadHelper();

  final ValueNotifier<VoiceChatState> state = ValueNotifier(
    VoiceChatState.idle,
  );
  final ValueNotifier<bool> isMuted = ValueNotifier(false);
  final ValueNotifier<bool> hasRemoteAudio = ValueNotifier(false);

  String? _roomId;
  String? _myUid;
  String? _remoteUid;
  bool _remoteDescSet = false;
  bool _iceRestarted = false;
  final List<RTCIceCandidate> _pendingRemoteCandidates = [];

  static final StreamController<IncomingCall?> _incomingController =
      StreamController<IncomingCall?>.broadcast();
  static Stream<IncomingCall?> get incomingStream => _incomingController.stream;

  static IncomingCall? _latestIncoming;
  static IncomingCall? get latestIncoming => _latestIncoming;

  static const String _collection = 'voice_rooms';

  static const _iceServers = [
    {'urls': 'stun:stun.l.google.com:19302'},
    {'urls': 'stun:stun1.l.google.com:19302'},
    {'urls': 'stun:stun2.l.google.com:19302'},
  ];

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
    await _remoteRenderer.initialize();
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
      if (event.track.kind == 'audio' && event.streams.isNotEmpty) {
        _attachRemoteAudio(event.streams[0]);
      }
    };

    _pc!.onConnectionState = (s) async {
      Logger.d('VoiceChatService: connection $s');
      if (s == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        state.value = VoiceChatState.connected;
        _iceRestarted = false;
      } else if (s ==
          RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
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
          'answer':
              '',
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        return;
      } catch (e) {
        Logger.e('VoiceChatService: ICE restart failed', error: e);
      }
    }
    state.value = VoiceChatState.ended;
    await _markEnded();
  }

  void _attachRemoteAudio(MediaStream stream) {
    _remoteRenderer.srcObject = stream;
    hasRemoteAudio.value = true;
  }

  RTCVideoRenderer get remoteRenderer => _remoteRenderer;

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
      await _flushRemoteCandidates();
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
      await _flushRemoteCandidates();
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
    _signalSub =
        withFirestoreTimeout(
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
            if (offer != null &&
                offer.isNotEmpty &&
                (answer == null || answer.isEmpty)) {
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
    _candidateSub =
        withFirestoreTimeout(
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
              final candidate = RTCIceCandidate(
                data['candidate'] as String,
                data['sdpMid'] as String,
                (data['sdpMLineIndex'] as num?)?.toInt() ?? 0,
              );
              unawaited(_addRemoteCandidate(candidate));
            }
          }
        });
  }

  Future<void> _addRemoteCandidate(RTCIceCandidate candidate) async {
    if (!_remoteDescSet || _pc == null) {
      _pendingRemoteCandidates.add(candidate);
      return;
    }
    try {
      await _pc!.addCandidate(candidate);
    } catch (e) {
      Logger.e('VoiceChatService._addRemoteCandidate failed', error: e);
    }
  }

  Future<void> _flushRemoteCandidates() async {
    if (!_remoteDescSet || _pc == null || _pendingRemoteCandidates.isEmpty) {
      return;
    }
    final candidates = List<RTCIceCandidate>.from(_pendingRemoteCandidates);
    _pendingRemoteCandidates.clear();
    for (final candidate in candidates) {
      await _addRemoteCandidate(candidate);
    }
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
    try {
      await _remoteRenderer.dispose();
    } catch (e) {
      debugPrint('[VoiceChatService] Failed to dispose remote renderer: $e');
    }
    _remoteDescSet = false;
    _iceRestarted = false;
    state.value = VoiceChatState.idle;
    isMuted.value = false;
    hasRemoteAudio.value = false;
  }

  static void watchIncoming({
    required String myUid,
    required String? partnerUid,
  }) {
    if (partnerUid == null || partnerUid.isEmpty) {
      _clearIncoming();
      return;
    }
    final sorted = [myUid, partnerUid]..sort();
    final roomId = '${sorted[0]}_${sorted[1]}';

    _clearIncoming();
    _incomingVoiceSnapshot = null;
    _incomingPartySnapshot = null;

    _incomingWatcherSub?.cancel();
    _incomingPartySub?.cancel();

    _incomingWatcherSub =
        withFirestoreTimeout(
          _incomingDb.collection(_collection).doc(roomId).snapshots(),
          label: 'voice_chat_incoming',
        ).listen((snap) {
          _incomingVoiceSnapshot = snap.exists ? snap : null;
          _evaluateIncoming(myUid: myUid, roomId: roomId);
        });

    _incomingPartySub =
        withFirestoreTimeout(
          _incomingDb.collection(_watchPartyCollection).doc(roomId).snapshots(),
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
          'VoiceChatService: failed to parse watch party room $roomId: $e',
        );
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
      episode: (data['episode'] is num)
          ? (data['episode'] as num).toInt()
          : null,
      seenAt: DateTime.now(),
    );

    final previous = _latestIncoming;
    if (previous != null &&
        previous.roomId == incoming.roomId &&
        previous.callerUid == incoming.callerUid &&
        previous.mediaTitle == incoming.mediaTitle) {
      return;
    }
    _latestIncoming = incoming;
    if (!_incomingController.isClosed) {
      _incomingController.add(incoming);
    }
  }

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

  void _installBeforeUnload() {
    _uninstallBeforeUnload();
    _beforeUnload.install(() {
      if (_roomId != null && state.value != VoiceChatState.ended) {
        _db
            .collection(_collection)
            .doc(_roomId)
            .update({
              'state': 'ended',
              'updatedAt': FieldValue.serverTimestamp(),
            })
            .catchError((Object e) {
              Logger.e('VoiceChatService beforeunload update failed', error: e);
            });
      }
      if (_localStream != null) {
        for (final track in _localStream!.getAudioTracks()) {
          try {
            track.stop();
          } catch (e) {
            debugPrint(
              '[VoiceChatService] Failed to stop track before unload: $e',
            );
          }
        }
      }
    });
  }

  void _uninstallBeforeUnload() {
    _beforeUnload.uninstall();
  }
}
