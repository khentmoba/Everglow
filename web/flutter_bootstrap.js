// Custom Flutter web bootstrap (replaces the SDK default template).
//
// The default template registers Flutter's own service worker, which is a
// deprecated self-unregistering shim — and Everglow ships its own worker
// (web/sw.js, cache-first shell + immutable assets) registered from
// index.html. Two workers on the same scope would flap and reload-loop, so
// this bootstrap intentionally passes NO serviceWorkerSettings: Flutter
// never touches service workers and ours owns the scope alone.
//
// Placeholders below are substituted at build time by flutter_tools.
// Clean up deprecated Intl.v8BreakIterator ahead of Flutter's browser detection
// so it cleanly chooses standard CanvasKit ICU text segmentation instead of
// triggering Chrome's deprecation warning.
try {
  if (typeof window !== 'undefined' && window.Intl) {
    delete window.Intl.v8BreakIterator;
  }
} catch (_) {
  try { window.Intl.v8BreakIterator = undefined; } catch (__) {}
}

// Hook Dart's deferred library loader so part files carry the build version
// query parameter, matching main.dart.js and preventing stale CDN/browser cache hits.
if (typeof window !== 'undefined') {
  window.dartDeferredLibraryLoader = function (uri, successCallback, errorCallback) {
    var script = document.createElement('script');
    script.type = 'text/javascript';
    var src = uri;
    if (window.__EVERGLOW_BUILD__ && src.indexOf('?v=') === -1 && src.indexOf('&v=') === -1) {
      src += (src.indexOf('?') === -1 ? '?v=' : '&v=') + encodeURIComponent(window.__EVERGLOW_BUILD__);
    }
    script.src = src;
    script.onload = successCallback;
    script.onerror = errorCallback;
    document.body.appendChild(script);
  };
}
{{flutter_js}}
{{flutter_build_config}}
var everglowConfig = {canvasKitVariant: "full"};
if (window.__everglowIsStandalone && window.__everglowIsStandalone()) {
  var host = document.getElementById('eg-app');
  if (host) {
    everglowConfig.hostElement = host;
    // Embedded Flutter measures the host, but does not supply keyboard
    // insets. Resize its surface to the visible area while editing instead.
    var viewport = window.visualViewport;
    function fitKeyboard() {
      var active = document.activeElement;
      var editing = active && (active.tagName === 'INPUT' || active.tagName === 'TEXTAREA' || active.isContentEditable);
      var covered = viewport && editing && viewport.scale === 1
        ? Math.max(0, window.innerHeight - viewport.height - viewport.offsetTop)
        : 0;
      host.style.bottom = covered + 'px';
    }
    if (viewport) {
      viewport.addEventListener('resize', fitKeyboard);
      viewport.addEventListener('scroll', fitKeyboard);
    }
    window.addEventListener('resize', fitKeyboard);
    document.addEventListener('focusin', fitKeyboard);
    document.addEventListener('focusout', function () { setTimeout(fitKeyboard, 0); });
    fitKeyboard();
  }
}
_flutter.loader.load({
  config: everglowConfig
});
