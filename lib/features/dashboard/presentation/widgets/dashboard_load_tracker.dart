import 'package:flutter/foundation.dart';

/// Signal keys for the dashboard's first-screen load progress.
///
/// One key per card in the first screenful (the Today zone + XP bar) plus
/// the auth session. A card marks its key exactly once — when it has
/// painted something final: real data, a cache hit, or a settled error
/// state. Never on a guess, a timer, or a retry that is still in flight.
///
/// Honesty rule (learned from the old boot veil): 100% means "the first
/// screen is ready". Sections below the fold load on scroll by design
/// ([DeferredSection]) and are deliberately NOT counted — no amount of
/// waiting can preload them, so counting them would stall the percent
/// or force a long fake wait.
abstract final class DashboardLoadSignal {
  static const String auth = 'auth';
  static const String memories = 'memories';
  static const String dates = 'dates';
  static const String letters = 'letters';
  static const String garden = 'garden';
  static const String stars = 'stars';
}

/// Counts real first-screen readiness signals and exposes them as a
/// 0.0–1.0 progress plus a warm "what's happening" label for Clair.
///
/// Owned by [DashboardScreen], provided down the tree so each first-screen
/// card can `mark()` its signal when its own load settles. Marking is
/// idempotent and safe to call when no veil is showing (later visits,
/// tests, or cards rendered outside the dashboard simply no-op through
/// the try/catch at the call site).
class DashboardLoadTracker extends ChangeNotifier {
  /// Signals in the order their labels are shown while pending.
  static const List<String> signals = [
    DashboardLoadSignal.auth,
    DashboardLoadSignal.memories,
    DashboardLoadSignal.dates,
    DashboardLoadSignal.letters,
    DashboardLoadSignal.garden,
    DashboardLoadSignal.stars,
  ];

  /// Warm label per pending signal, shown under the percent.
  static const Map<String, String> labels = {
    DashboardLoadSignal.auth: 'opening the door…',
    DashboardLoadSignal.memories: 'gathering memories…',
    DashboardLoadSignal.dates: 'checking your dates…',
    DashboardLoadSignal.letters: 'unsealing letters…',
    DashboardLoadSignal.garden: 'waking the garden…',
    DashboardLoadSignal.stars: 'counting your stars…',
  };

  final Set<String> _done = {};

  int get done => _done.length;
  int get total => signals.length;

  /// 0.0–1.0 fraction of first-screen signals that have reported ready.
  double get progress => total == 0 ? 1.0 : done / total;

  /// True once every first-screen signal has reported ready.
  bool get isComplete => done >= total;

  /// Label of the first signal still pending, so the loader always says
  /// what Clair is actually waiting on.
  String get currentLabel {
    for (final signal in signals) {
      if (!_done.contains(signal)) return labels[signal]!;
    }
    return 'loading your story…';
  }

  /// Records [signal] as ready. Unknown keys are ignored; repeats no-op.
  void mark(String signal) {
    if (!signals.contains(signal)) return;
    if (_done.add(signal)) notifyListeners();
  }
}
