try {
  if (typeof window !== 'undefined' && window.Intl) {
    delete window.Intl.v8BreakIterator;
  }
} catch (_) {
  try { window.Intl.v8BreakIterator = undefined; } catch (__) {}
}

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
  }
}
_flutter.loader.load({
  config: everglowConfig
});
