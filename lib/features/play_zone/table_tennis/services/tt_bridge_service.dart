import 'dart:async';
import 'dart:js_interop';
import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

import '../models/tt_room.dart';
import 'tt_multiplayer_service.dart';

class TTBridgeService {
  final TTMultiplayerService _mpService;
  String? _roomId;
  StreamSubscription? _firestoreSub;
  bool _isHost = false;
  int _localTick = 0;
  Timer? _paddleThrottle;
  Timer? _ballThrottle;
  double _lastSentPaddleY = -1;
  bool _running = false;

  String? get roomId => _roomId;
  bool get isHost => _isHost;

  TTBridgeService({
    required TTMultiplayerService mpService,
  }) : _mpService = mpService;

  void connect({
    required String roomId,
    required bool isHost,
  }) {
    _roomId = roomId;
    _isHost = isHost;
    _localTick = 0;
    _running = true;

    final iframe = _findIframe();
    if (iframe != null) {
      final side = isHost ? 'near' : 'far';
      _postMessage(iframe, 'START_MP', <String, dynamic>{'isHost': isHost, 'side': side});
    }

    _firestoreSub = _mpService.watchRoom(roomId).listen((room) {
      if (!_running) return;
      final f = _findIframe();
      if (f == null) return;
      _postMessage(f, 'REMOTE_PADDLE', <String, dynamic>{
        'y': isHost ? room.guestPaddleY : room.hostPaddleY,
      });
      if (!isHost) {
        _postMessage(f, 'REMOTE_BALL', <String, dynamic>{
          'x': room.ball.x,
          'y': room.ball.y,
          'vx': room.ball.vx,
          'vy': room.ball.vy,
        });
      }
      _postMessage(f, 'REMOTE_SCORE', <String, dynamic>{
        'hostScore': room.hostScore,
        'guestScore': room.guestScore,
      });
    });

    _paddleThrottle = Timer.periodic(const Duration(milliseconds: 66), (_) {
      _sendPaddle();
    });

    if (isHost) {
      _ballThrottle = Timer.periodic(const Duration(milliseconds: 66), (_) {
        _sendBallState();
      });
    }
  }

  void _postMessage(web.HTMLIFrameElement iframe, String type, Map<String, dynamic> data) {
    try {
      final msg = <String, dynamic>{'type': type, ...data};
      final jsMsg = msg.jsify();
      iframe.contentWindow?.postMessage(jsMsg!, '*'.toJS);
    } catch (e) {
      debugPrint('[TTBridgeService] Failed to post message to iframe: $e');
    }
  }

  web.HTMLIFrameElement? _findIframe() {
    try {
      return web.document.querySelector('iframe[data-everglow-tt="1"]')
          as web.HTMLIFrameElement?;
    } catch (e) {
      debugPrint('[TTBridgeService] Failed to find iframe: $e');
      return null;
    }
  }

  void _sendPaddle() {
    if (_roomId == null) return;
    final paddle = TTMultiplayerState.localPaddleY;
    if (paddle < 0) return;
    _lastSentPaddleY = paddle;
    _localTick++;
    if (_isHost) {
      _mpService.writeHostState(
        roomId: _roomId!,
        localTick: _localTick,
        hostPaddleY: paddle,
        ball: BallState.fromMap(TTMultiplayerState.latestBallState),
        hostScore: TTMultiplayerState.latestHostScore,
        guestScore: TTMultiplayerState.latestGuestScore,
        status: TTRoomStatus.playing,
      );
    } else {
      _mpService.writeGuestPaddle(
        roomId: _roomId!,
        localTick: _localTick,
        guestPaddleY: paddle,
      );
    }
  }

  void _sendBallState() {
    if (_roomId == null || !_isHost) return;
    final ballMap = TTMultiplayerState.latestBallState;
    if (ballMap == null) return;
    _localTick++;
    _mpService.writeHostState(
      roomId: _roomId!,
      localTick: _localTick,
      hostPaddleY: _lastSentPaddleY,
      ball: BallState.fromMap(ballMap),
      hostScore: TTMultiplayerState.latestHostScore,
      guestScore: TTMultiplayerState.latestGuestScore,
      status: TTRoomStatus.playing,
    );
  }

  void disconnect() {
    _running = false;
    _firestoreSub?.cancel();
    _paddleThrottle?.cancel();
    _ballThrottle?.cancel();
    if (_roomId != null && _isHost) {
      _mpService.endMatch(roomId: _roomId!);
    }
    _roomId = null;
  }

  void dispose() {
    disconnect();
  }
}

class TTMultiplayerState {
  static double localPaddleY = -1;
  static Map<String, dynamic>? latestBallState;
  static int latestHostScore = 0;
  static int latestGuestScore = 0;

  static void handleMessage(web.MessageEvent event) {
    final data = event.data;
    if (data is! Map) return;
    final map = Map<String, dynamic>.from(data as Map);
    final type = map['type'] as String?;
    switch (type) {
      case 'LOCAL_PADDLE':
        localPaddleY = (map['y'] as num?)?.toDouble() ?? 0.5;
        break;
      case 'LOCAL_BALL':
        latestBallState = <String, dynamic>{
          'x': (map['x'] as num?)?.toDouble() ?? 0,
          'y': (map['y'] as num?)?.toDouble() ?? 0,
          'vx': (map['vx'] as num?)?.toDouble() ?? 0,
          'vy': (map['vy'] as num?)?.toDouble() ?? 0,
        };
        break;
      case 'LOCAL_SCORE':
        latestHostScore = (map['hostScore'] as int?) ?? 0;
        latestGuestScore = (map['guestScore'] as int?) ?? 0;
        break;
    }
  }
}
