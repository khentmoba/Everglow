library;

class CinesrcEvent {
  final String name;

  final double? currentTime;

  final String? command;
  final Object? result;

  const CinesrcEvent(this.name, [this.currentTime, this.command, this.result]);
}

const _eventNames = {
  'ready',
  'play',
  'pause',
  'timeupdate',
  'seeking',
  'seeked',
  'ended',
  'response',
};

CinesrcEvent? parseCinesrcEvent(Object? raw) {
  if (raw is! Map) return null;
  final type = raw['type'];
  if (type is! String || !type.startsWith('cinesrc:')) return null;
  final name = type.substring('cinesrc:'.length);
  if (!_eventNames.contains(name)) return null;
  final time = raw['currentTime'];
  final seconds = time is num && time.isFinite && time >= 0
      ? time.toDouble()
      : null;
  final command = raw['command'];
  final result = raw['result'];
  return CinesrcEvent(
    name,
    seconds,
    command is String ? command : null,
    result is bool || result is num ? result : null,
  );
}

Map<String, Object?> cinesrcCommand(
  String command, [
  List<Object?> args = const [],
]) => {'type': 'cinesrc:command', 'command': command, 'args': args};

bool isUserSeek({
  required double expectedSeconds,
  required double reportedSeconds,
  double thresholdSeconds = 2.0,
}) => (reportedSeconds - expectedSeconds).abs() > thresholdSeconds;
