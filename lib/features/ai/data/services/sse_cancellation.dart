/// Stops the current transport without adding another server request.
class SseCancellation {
  bool _cancelled = false;
  void Function()? _abort;

  bool get isCancelled => _cancelled;

  void attach(void Function()? abort) {
    _abort = abort;
    if (_cancelled) abort?.call();
  }

  void cancel() {
    _cancelled = true;
    _abort?.call();
  }
}
