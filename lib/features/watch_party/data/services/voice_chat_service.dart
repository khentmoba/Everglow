import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

enum VoiceChatState { idle, calling, connected, ended }

class VoiceChatService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  RTCPeerConnection? _pc;
  MediaStream? _localStream;
  StreamSubscription<DocumentSnapshot>? _signalSub;
  StreamSubscription<QuerySnapshot>? _candidateSub;

  final ValueNotifier<VoiceChatState> state =
      ValueNotifier(VoiceChatState.idle);
  final ValueNotifier<bool> isMuted = ValueNotifier(false);

  String? _roomId;
  String? _myUid;
  String? _remoteUid;
  bool _remoteDescSet = false;

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
  }) async {
    _roomId = roomId;
    _myUid = myUid;
    _remoteUid = remoteUid;

    try {
      await _getMedia();
      await _createPC();
      _listenSignal();
      _listenCandidates();

      if (isCaller) {
        await _createOffer();
      }
    } catch (e) {
      debugPrint('VoiceChatService.init failed: $e');
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
    _pc = await createPeerConnection({'iceServers': _iceServers});

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

    _pc!.onConnectionState = (s) {
      debugPrint('VoiceChatService: connection $s');
      if (s == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        state.value = VoiceChatState.connected;
      } else if (s == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
          s == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        state.value = VoiceChatState.ended;
      }
    };

    if (_localStream != null) {
      for (final track in _localStream!.getAudioTracks()) {
        await _pc!.addTrack(track, _localStream!);
      }
    }
  }

  void _attachRemoteAudio(MediaStream stream) {
    _pc!.onAddStream = (stream) {
      hasRemoteAudio.value = true;
    };
  }

  final ValueNotifier<bool> hasRemoteAudio = ValueNotifier(false);

  Future<void> _createOffer() async {
    try {
      final offer = await _pc!.createOffer({'offerToReceiveAudio': true});
      await _pc!.setLocalDescription(offer);
      final offerJson = jsonEncode(offer.toMap());

      await _db.collection(_collection).doc(_roomId).set({
        'callerUid': _myUid,
        'calleeUid': _remoteUid,
        'state': 'calling',
        'offer': offerJson,
        'answer': '',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      state.value = VoiceChatState.calling;
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

      state.value = VoiceChatState.calling;
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
    if (_roomId != null) {
      try {
        await _db.collection(_collection).doc(_roomId).update({
          'state': 'ended',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } catch (_) {}
    }
    await dispose();
  }

  Future<void> dispose() async {
    _signalSub?.cancel();
    _candidateSub?.cancel();
    _signalSub = null;
    _candidateSub = null;
    if (_pc != null) {
      await _pc!.close();
      _pc = null;
    }
    if (_localStream != null) {
      for (final track in _localStream!.getAudioTracks()) {
        track.stop();
      }
      _localStream = null;
    }
    _remoteDescSet = false;
    state.value = VoiceChatState.idle;
    isMuted.value = false;
    hasRemoteAudio.value = false;
  }

}
