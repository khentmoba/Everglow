import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// The JS object every global lives on. `globalThis` is the one name that is
/// guaranteed to already exist, so this never needs creating.
@JS('globalThis')
external JSObject get _globalThis;

/// Publishes the meter's reading as `window.__everglowPerf` on web.
///
/// Why a JS global: the frame meter paints into a canvas, so the numbers are
/// invisible to devtools, automation and screenshots-of-text. This mirror lets
/// a browser session be *measured* (scroll the dashboard, read the numbers)
/// instead of guessed at. Only ever called while the meter switch is on.
///
/// Uses [globalContext] rather than an `@JS() external set` on the bare
/// identifier. The bare form compiles to a plain `__everglowPerf = ...`
/// assignment, which throws a `ReferenceError` when the global does not exist
/// yet and the script runs in strict mode (module or bundled output) — and the
/// throw was being swallowed by the catch below, so the mirror silently never
/// appeared and every measurement had to be eyeballed off a screenshot.
/// Assigning a property on `globalContext` creates it explicitly and works in
/// both modes.
void publishPerfSnapshot(Map<String, double> snapshot) {
  try {
    _globalThis['__everglowPerf'] = snapshot.jsify();
  } catch (_) {
    // Nothing here may break the app: the overlay already shows these numbers.
  }
}

/// Disabling the HUD must not leave a stale sample or disposed reset handler.
void clearPerfProbe() {
  _globalThis['__everglowPerf'] = null;
  _globalThis['__everglowResetPerf'] = null;
}

/// Available only from the compile-time gated synthetic bench route.
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
