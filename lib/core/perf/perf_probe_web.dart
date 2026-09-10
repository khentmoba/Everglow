import 'dart:js_interop';

/// Publishes the meter's reading as `window.__everglowPerf` on web.
///
/// Why a JS global: the frame meter paints into a canvas, so the numbers are
/// invisible to devtools, automation and screenshots-of-text. This mirror lets
/// a browser session be *measured* (scroll the dashboard, read the numbers)
/// instead of guessed at. Only ever called while the meter switch is on.
@JS('__everglowPerf')
external set _everglowPerf(JSObject? value);

void publishPerfSnapshot(Map<String, double> snapshot) {
  try {
    _everglowPerf = snapshot.jsify() as JSObject;
  } catch (_) {
    // Nothing here may break the app: the overlay already shows these numbers.
  }
}
