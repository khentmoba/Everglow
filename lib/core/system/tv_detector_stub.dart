/// Non-browser fallback for [tv_detector_web.dart].
///
/// In VM unit tests and native builds, TV browser detection returns false.
class TvDetector {
  TvDetector._();

  static bool detectTvBrowser() => false;
}
