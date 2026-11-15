Future<T?> firstUsableChapterSource<T>(
  List<Future<T?>> attempts,
  bool Function(T) isUsable,
) async {
  final settled = attempts.map((future) => future.then<T?>(
    (value) => value,
    onError: (Object _, StackTrace _) => null,
  )).toList();
  for (final attempt in settled) {
    final value = await attempt;
    if (value != null && isUsable(value)) return value;
  }
  return null;
}
