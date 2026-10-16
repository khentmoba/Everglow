import 'dart:async';
import 'dart:js_interop';
import 'dart:math' as math;
import '../../../../../core/utils/latest_value_writer.dart';
import '../../../../../core/utils/logger.dart';
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
  Timer? _stateTimer;
  String _lastState = '';
  int _generation = 0;
  late final _writer = LatestValueWriter<Future<void> Function()>(
    write: (save) => save(),
    onError: (error, stack) =>
        Logger.e('Table tennis sync failed', error: error, stackTrace: stack),
  );
  bool _running = false;

  String? get roomId => _roomId;
  bool get isHost => _isHost;

  TTBridgeService({required TTMultiplayerService mpService})
    : _mpService = mpService;

  void connect({required String roomId, required bool isHost}) {
    _stateTimer?.cancel();
    _firestoreSub?.cancel();
    _writer.clearPending();
    ++_generation;
    _roomId = roomId;
    _isHost = isHost;
    _localTick = 0;
    _running = true;
    _lastState = '';

    final iframe = _findIframe();
    if (iframe != null) {
      final side = isHost ? 'near' : 'far';
      _postMessage(iframe, 'START_MP', <String, dynamic>{
        'isHost': isHost,
        'side': side,
      });
    }

    _firestoreSub = _mpService.watchRoom(roomId).listen((room) {
      if (!_running || _roomId != roomId) return;
      _localTick = math.max(_localTick, room.lastTick);
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

    _stateTimer = Timer.periodic(
      const Duration(milliseconds: 200),
      (_) => _sendState(),
    );
  }

  void _postMessage(
    web.HTMLIFrameElement iframe,
    String type,
    Map<String, dynamic> data,
  ) {
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

  void _sendState() {
    final roomId = _roomId;
    final paddle = TTMultiplayerState.localPaddleY;
    if (!_running || roomId == null || paddle < 0) return;
    final ball = BallState.fromMap(TTMultiplayerState.latestBallState);
    final hostScore = TTMultiplayerState.latestHostScore;
    final guestScore = TTMultiplayerState.latestGuestScore;
    final signature = _isHost
        ? '$paddle|${ball.x}|${ball.y}|${ball.vx}|${ball.vy}|$hostScore|$guestScore'
        : '$paddle';
    if (_lastState == signature) return;
    _lastState = signature;
    final generation = _generation;
    final host = _isHost;
    _writer.add(() async {
      if (!_running || generation != _generation) return;
      if (host) {
        await _mpService.writeHostState(
          roomId: roomId,
          localTick: ++_localTick,
          hostPaddleY: paddle,
          ball: ball,
          hostScore: hostScore,
          guestScore: guestScore,
          status: TTRoomStatus.playing,
        );
      } else {
        await _mpService.writeGuestPaddle(
          roomId: roomId,
          localTick: ++_localTick,
          guestPaddleY: paddle,
        );
      }
    });
  }

  void disconnect() {
    _running = false;
    _firestoreSub?.cancel();
    _stateTimer?.cancel();
    ++_generation;
    _writer.clearPending();
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
    final data = event.data.dartify();
    if (data is! Map) return;
    final map = Map<String, dynamic>.from(data);
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
