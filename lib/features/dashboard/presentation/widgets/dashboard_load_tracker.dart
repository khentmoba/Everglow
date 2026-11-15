import 'package:flutter/foundation.dart';

abstract final class DashboardLoadSignal {
  static const String auth = 'auth';
  static const String memories = 'memories';
  static const String dates = 'dates';
  static const String letters = 'letters';
  static const String garden = 'garden';
  static const String stars = 'stars';
}

class DashboardLoadTracker extends ChangeNotifier {
  static const List<String> signals = [
    DashboardLoadSignal.auth,
    DashboardLoadSignal.memories,
    DashboardLoadSignal.dates,
    DashboardLoadSignal.letters,
    DashboardLoadSignal.garden,
    DashboardLoadSignal.stars,
  ];

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

  double get progress => total == 0 ? 1.0 : done / total;

  bool get isComplete => done >= total;

  String get currentLabel {
    for (final signal in signals) {
      if (!_done.contains(signal)) return labels[signal]!;
    }
    return 'loading your story…';
  }

  void mark(String signal) {
    if (!signals.contains(signal)) return;
    if (_done.add(signal)) notifyListeners();
  }
}
