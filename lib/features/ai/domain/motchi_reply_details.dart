/// Verified memories and execution receipts attached to one assistant reply.
/// These are transport data, not claims extracted from the model's prose.
class MotchiReplyDetails {
  final List<Map<String, dynamic>> memories;
  final List<Map<String, dynamic>> steps;
  final bool interrupted;

  const MotchiReplyDetails({
    this.memories = const [],
    this.steps = const [],
    this.interrupted = false,
  });

  bool get isEmpty => memories.isEmpty && steps.isEmpty && !interrupted;

  /// Only a step that can leave something half-saved demands action. Reads
  /// (web_search, read_web_page, browse_web) are informational: a page
  /// Motchi could not open changes where the answer came from, which the
  /// reply already says, and leaves Clair nothing to finish herself.
  /// Anything not explicitly marked `write: false` still counts — older
  /// saved replies predate that flag, and silence is the wrong default.
  bool get needsAttention {
    if (steps.any(_needsAction)) return true;
    if (!interrupted) return false;
    // An interruption only demands finishing steps if there was an action/write
    // that could be half-done. Pure reads leave nothing to save or finish.
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
    );
  }

  /// Citation markers are invisible, including a marker split across tokens.
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

  /// Only explicitly named owners count. The person who saved a fact is
  /// not necessarily the person it describes.
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
