// TV browser detector for Smart TV, Google TV, Apple TV, Fire TV, Tizen, webOS.
//
// Conditional export so VM tests and native builds never touch `package:web`:
// * browser build -> [tv_detector_web.dart]
// * anything else  -> [tv_detector_stub.dart]
export 'tv_detector_web.dart'
    if (dart.library.io) 'tv_detector_stub.dart';
