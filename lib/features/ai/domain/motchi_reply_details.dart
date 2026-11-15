class MotchiReplyDetails {
  final List<Map<String, dynamic>> memories;
  final List<Map<String, dynamic>> steps;
  final bool interrupted;
  final List<Map<String, dynamic>> recommendations;

  const MotchiReplyDetails({
    this.memories = const [],
    this.steps = const [],
    this.interrupted = false,
    this.recommendations = const [],
  });

  bool get isEmpty =>
      memories.isEmpty &&
      steps.isEmpty &&
      recommendations.isEmpty &&
      !interrupted;

  bool get needsAttention {
    if (steps.any(_needsAction)) return true;
    if (!interrupted) return false;
    return steps.isEmpty || steps.any((s) => s['write'] != false);
  }

  static bool _needsAction(Map<String, dynamic> step) =>
      step['status'] != 'done' &&
      (step['write'] != false || step['status'] == 'unknown');

  String get summary {
    if (interrupted) return 'Stopped before finishing — check the steps below.';
    if (steps.any((s) => s['status'] == 'unknown' && _needsAction(s))) {
      return 'Some actions could not be confirmed. Check before trying again.';
    }
    if (steps.any(
      (s) =>
          _needsAction(s) &&
          (s['status'] == 'failed' || s['status'] == 'unscheduled'),
    )) {
      return 'Some steps still need attention.';
    }
    if (steps.any((s) => s['status'] == 'waiting')) {
      return 'Waiting for your choice or confirmation.';
    }
    if (steps.isNotEmpty && !steps.any((s) => s['write'] == true)) {
      return 'Information found — nothing saved yet.';
    }
    return 'Here is what happened.';
  }

  Map<String, dynamic> toJson() => {
    'memories': memories,
    'steps': steps,
    'interrupted': interrupted,
    if (recommendations.isNotEmpty) 'recommendations': recommendations,
  };

  factory MotchiReplyDetails.fromJson(Map<String, dynamic> json) {
    List<Map<String, dynamic>> records(dynamic value) => value is List
        ? value
              .whereType<Map>()
              .map((v) => Map<String, dynamic>.from(v))
              .toList()
        : [];
    return MotchiReplyDetails(
      memories: records(json['memories']),
      steps: records(json['steps']),
      interrupted: json['interrupted'] == true,
      recommendations: records(json['recommendations']),
    );
  }

  static MotchiReplyDetails fromResults(
    List<Map<String, dynamic>> results, {
    bool interrupted = false,
    List<String> activeTools = const [],
  }) {
    final finalDetails = results
        .where((r) => r['tool'] == 'reply_details')
        .lastOrNull;
    final details = finalDetails == null
        ? const MotchiReplyDetails()
        : MotchiReplyDetails.fromJson(finalDetails);
    final steps = List<Map<String, dynamic>>.of(details.steps);
    if (finalDetails == null) {
      for (final result in results.where((r) => r['step'] is Map)) {
        final step = Map<String, dynamic>.from(result['step'] as Map);
        final pending = steps.indexWhere(
          (s) =>
              s['status'] == 'waiting' &&
              s['tool'] == step['tool'] &&
              '${s['target'] ?? ''}'.isNotEmpty &&
              s['target'] == step['target'],
        );
        if (pending >= 0) {
          steps[pending] = step;
        } else {
          steps.add(step);
        }
      }
    }
    if (interrupted) {
      for (final tool in activeTools) {
        steps.add({'tool': tool, 'status': 'unknown', 'title': ''});
      }
    }
    return MotchiReplyDetails(
      memories: details.memories,
      steps: steps,
      interrupted: interrupted || details.interrupted,
      recommendations: details.recommendations,
    );
  }

  static String visibleText(String text) {
    final clean = text.replaceAll(RegExp(r'\[\[memory:[^\]\r\n]*\]\]'), '');
    final start = clean.lastIndexOf('[[');
    if (start < 0) return clean;
    final tail = clean.substring(start);
    if ('[[memory:'.startsWith(tail) ||
        (tail.startsWith('[[memory:') &&
            !tail.contains(']]') &&
            !tail.contains('\n'))) {
      return clean.substring(0, start);
    }
    return clean;
  }

  static String owner(Map<String, dynamic> memory) {
    final subject = '${memory['subject'] ?? ''}'.trim().toLowerCase();
    if (subject == 'clair') return 'Clair';
    if (subject == 'khent') return 'Khent';
    if (subject == 'khent and clair' || subject == 'clair and khent') {
      return 'Both of you';
    }
    return 'Owner not specified';
  }
}
