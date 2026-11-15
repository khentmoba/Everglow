import 'dart:js_interop';
import 'dart:js_interop_unsafe';

@JS('globalThis')
external JSObject get _globalThis;

void publishPerfSnapshot(Map<String, double> snapshot) {
  try {
    _globalThis['__everglowPerf'] = snapshot.jsify();
  } catch (_) {
    // Nothing here may break the app: the overlay already shows these numbers.
  }
}

void clearPerfProbe() {
  _globalThis['__everglowPerf'] = null;
  _globalThis['__everglowResetPerf'] = null;
}

void registerBenchScroll(Map<String, Object> Function()? readScroll) {
  if (readScroll == null) {
    _globalThis['__everglowBenchScroll'] = null;
  } else {
    _globalThis['__everglowBenchScroll'] = (() => readScroll().jsify()).toJS;
  }
}

void registerPerfReset(void Function() onReset) {
  try {
    _globalThis['__everglowResetPerf'] = (() {
      onReset();
    }).toJS;
  } catch (_) {
    // Optional JS interop bridge in non-browser or test environments.
  }
}

void recordPerfMark(String name) {
  try {
    final marks = _globalThis['__everglowMarks'] as JSArray<JSAny?>?;
    final mark = {'name': name, 'at': _now()}.jsify();
    if (marks == null) {
      _globalThis['__everglowMarks'] = [mark].toJS;
    } else {
      marks.callMethod('push'.toJS, mark);
    }
  } catch (_) {
    // A diagnostic mark must never break navigation.
  }
}

@JS('performance.now')
external double _now();
