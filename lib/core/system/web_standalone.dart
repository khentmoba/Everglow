// Standalone-web (Add to Home Screen) top inset.
//
// Conditional export so VM tests and native builds never touch `package:web`:
//
// * browser build -> [web_standalone_web.dart] (real detection + widget)
// * anything else  -> [web_standalone_stub.dart] (always zero, child as-is)
//
// Scope notes: this exists ONLY for the installed-web-app case
// (`display-mode: standalone` / iOS `navigator.standalone`). Normal mobile
// Safari keeps Safari's own top bar, so the inset stays 0 there by design.
export 'web_standalone_web.dart'
    if (dart.library.io) 'web_standalone_stub.dart';
