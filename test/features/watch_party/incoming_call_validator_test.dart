import 'package:flutter_test/flutter_test.dart';
import 'package:everglow/features/watch_party/data/services/incoming_call_validator.dart';

void main() {
  const myUid = 'clair-uid';
  const callerUid = 'khent-uid';
  final now = DateTime(2026, 8, 13, 12);

  Map<String, dynamic> voiceCalling() => {
        'callerUid': callerUid,
        'calleeUid': myUid,
        'state': 'calling',
      };

  test('shows the banner while the party room is live', () {
    expect(
      isLiveIncomingCall(
        myUid: myUid,
        voiceData: voiceCalling(),
        partyActive: true,
        partyUpdatedAt: now.subtract(const Duration(seconds: 10)),
        now: now,
      ),
      isTrue,
    );
  });

  test('hides the banner when the party room is inactive', () {
    expect(
      isLiveIncomingCall(
        myUid: myUid,
        voiceData: voiceCalling(),
        partyActive: false,
        partyUpdatedAt: now.subtract(const Duration(seconds: 10)),
        now: now,
      ),
      isFalse,
    );
  });

  test('hides the banner for a stale voice room with no live heartbeat', () {
    expect(
      isLiveIncomingCall(
        myUid: myUid,
        voiceData: voiceCalling(),
        partyActive: true,
        partyUpdatedAt: now.subtract(const Duration(hours: 2)),
        now: now,
      ),
      isFalse,
    );
  });

  test('allows small clock skew between the two devices', () {
    expect(
      isLiveIncomingCall(
        myUid: myUid,
        voiceData: voiceCalling(),
        partyActive: true,
        partyUpdatedAt: now.add(const Duration(seconds: 30)),
        now: now,
      ),
      isTrue,
    );
  });

  test('hides the caller own banner', () {
    expect(
      isLiveIncomingCall(
        myUid: callerUid,
        voiceData: voiceCalling(),
        partyActive: true,
        partyUpdatedAt: now,
        now: now,
      ),
      isFalse,
    );
  });

  test('hides the banner once the voice room ends', () {
    expect(
      isLiveIncomingCall(
        myUid: myUid,
        voiceData: {...voiceCalling(), 'state': 'ended'},
        partyActive: true,
        partyUpdatedAt: now,
        now: now,
      ),
      isFalse,
    );
  });
}
