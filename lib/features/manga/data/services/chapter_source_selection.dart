/// All attempts start together, but lower-priority sources cannot delay a hit.
Future<T?> firstUsableChapterSource<T>(
  List<Future<T?>> attempts,
  bool Function(T) isUsable,
) async {
  // Attach error handlers immediately, including attempts we will not await.
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
