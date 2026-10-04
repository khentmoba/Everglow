/// Pure helpers for talking to the CineSrc player through our
/// `web/embed.html` wrapper (which relays `cinesrc:*` messages).
///
/// CineSrc can be told to play, pause and seek, and it reports what the
/// viewer does. That is what lets a pause on one phone pause the other.
/// Kept free of browser types so unit tests cover it.
library;

/// One playback event reported by the player.
class CinesrcEvent {
  /// 'ready' | 'play' | 'pause' | 'timeupdate' | 'seeking' | 'seeked' |
  /// 'ended' | 'response'
  final String name;

  /// Player position in seconds, when the event carries it.
  final double? currentTime;

  /// For 'response': the command being answered and its answer.
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

/// Parses a message from the wrapper. Returns null for anything that is
/// not a playback event (episode changes, foreign pages, junk).
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

/// Message that asks the player to run [command] (`play`, `pause`,
/// `seek` with `[seconds]`, `setMuted` with `[bool]`).
Map<String, Object?> cinesrcCommand(
  String command, [
  List<Object?> args = const [],
]) => {'type': 'cinesrc:command', 'command': command, 'args': args};

/// A seek counts as "the viewer jumped" only when the player lands far
/// from where we expected it to be. Smaller differences are normal
/// jitter and must not be broadcast.
bool isUserSeek({
  required double expectedSeconds,
  required double reportedSeconds,
  double thresholdSeconds = 2.0,
}) => (reportedSeconds - expectedSeconds).abs() > thresholdSeconds;
