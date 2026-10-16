import 'dart:async';

/// Serialize network saves, retaining only the newest value while one is busy.
class LatestValueWriter<T> {
  LatestValueWriter({required this.write, required this.onError});

  final Future<void> Function(T value) write;
  final void Function(Object error, StackTrace stack) onError;
  T? _pending;
  bool _writing = false;
  Completer<void>? _settled;
  Future<void> get settled => _settled?.future ?? Future.value();

  Future<void> add(T value) {
    _pending = value;
    if (!_writing) {
      _writing = true;
      _settled = Completer<void>();
      final done = _settled!.future;
      unawaited(_drain());
      return done;
    }
    return _settled!.future;
  }

  void clearPending() => _pending = null;

  Future<void> _drain() async {
    while (_pending != null) {
      final value = _pending as T;
      _pending = null;
      try {
        await write(value);
      } catch (error, stack) {
        onError(error, stack);
      }
    }
    _writing = false;
    _settled!.complete();
    _settled = null;
  }
}
