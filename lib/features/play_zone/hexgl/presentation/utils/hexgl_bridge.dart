import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

import 'dart:ui_web' as ui_web;

/// Bridge between Flutter and the embedded HexGL iframe.
class HexGLBridge {
  final web.HTMLIFrameElement _iframe;
  final StreamController<HexGLMessage> _messages =
      StreamController<HexGLMessage>.broadcast();
  late final web.EventListener _listener;

  bool _disposed = false;

  HexGLBridge._(this._iframe) {
    _listener = ((web.Event e) {
      final dynamic data = (e as web.MessageEvent).data;
      if (data == null) return;
      try {
        final message = HexGLMessage.tryParse(data);
        if (message != null) {
          _messages.add(message);
        }
      } catch (err) {
        if (kDebugMode) {
          debugPrint('HexGLBridge message parse error: $err');
        }
      }
    }).toJS;
    web.window.addEventListener('message', _listener);
  }

  static HexGLBridge create({
    required String src,
    required String viewId,
  }) {
    final iframe = web.document.createElement('iframe') as web.HTMLIFrameElement
      ..src = src
      ..style.border = '0'
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.display = 'block'
      ..allow = 'autoplay; fullscreen; xr-spatial-tracking'
      ..setAttribute('allowfullscreen', 'true')
      ..setAttribute('webkitallowfullscreen', 'true')
      ..setAttribute('mozallowfullscreen', 'true')
      ..title = 'HexGL'
      ..tabIndex = -1;

    ui_web.platformViewRegistry.registerViewFactory(viewId, (int viewId) {
      iframe.setAttribute('tabindex', '0');
      return iframe;
    });

    return HexGLBridge._(iframe);
  }

  Stream<HexGLMessage> get messages => _messages.stream;

  web.HTMLIFrameElement get iframeElement => _iframe;

  void _post(Map<String, dynamic> msg) {
    if (_disposed) return;
    try {
      final js = msg.jsify();
      if (js == null) return;
      final w = _iframe.contentWindow;
      if (w == null) return;
      w.postMessage(js, '*'.toJS);
    } catch (err) {
      if (kDebugMode) debugPrint('HexGLBridge post error: $err');
    }
  }

  void sendInput(String key, {required bool value, String? driftSide}) {
    _post({
      'source': 'everglow-parent',
      'type': 'input',
      'key': key,
      'value': value,
      if (driftSide != null) 'driftSide': driftSide,
    });
  }

  void sendCustomBoost(bool value) {
    _post({
      'source': 'everglow-parent',
      'type': 'input',
      'key': 'customBoost',
      'value': value,
    });
  }

  void restart() => _post({'source': 'everglow-parent', 'type': 'restart'});

  void reset() => _post({'source': 'everglow-parent', 'type': 'reset'});

  void ping() => _post({'source': 'everglow-parent', 'type': 'ping'});

  void loadReplay(List<List<double>>? replay, {bool autoStart = false}) {
    _post({
      'source': 'everglow-parent',
      'type': 'loadReplay',
      'replay': replay,
      'autoStart': autoStart,
    });
  }

  void loadAndStartReplay(List<List<double>>? replay) {
    _post({
      'source': 'everglow-parent',
      'type': 'loadAndStartReplay',
      'replay': replay,
    });
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    try {
      web.window.removeEventListener('message', _listener);
    } catch (_) {}
    _messages.close();
  }
}

@immutable
class HexGLMessage {
  final String type;
  final Map<String, dynamic> _data;

  const HexGLMessage._(this.type, this._data);

  static HexGLMessage? tryParse(dynamic raw) {
    // raw is whatever MessageEvent.data is. We dartify it via JS interop.
    try {
      final jsAny = raw as JSAny;
      final dart = jsAny.dartify();
      if (dart is! Map) return null;
      final map = Map<String, dynamic>.from(dart);
      if (map['source'] != 'hexgl-embed') return null;
      final type = (map['type'] as String?) ?? 'unknown';
      return HexGLMessage._(type, map);
    } catch (_) {
      return null;
    }
  }

  int? get finishTimeMs {
    final v = _data['finishTime'];
    if (v is num) return v.toInt();
    return null;
  }

  String? get resultLabel => _data['resultLabel'] as String?;

  List<int> get lapTimesMs {
    final v = _data['lapTimes'];
    if (v is! List) return const [];
    return v
        .whereType<num>()
        .map((e) => e.toInt())
        .where((e) => e > 0)
        .toList();
  }

  List<List<double>>? get replay {
    final v = _data['replay'];
    if (v is! List) return null;
    final out = <List<double>>[];
    for (final row in v) {
      if (row is List) {
        out.add(row.whereType<num>().map((e) => e.toDouble()).toList());
      }
    }
    return out;
  }

  String? get errorMessage => _data['message'] as String?;

  int? get progressLoaded {
    final v = _data['loaded'];
    if (v is num) return v.toInt();
    return null;
  }

  int? get progressTotal {
    final v = _data['total'];
    if (v is num) return v.toInt();
    return null;
  }
}
