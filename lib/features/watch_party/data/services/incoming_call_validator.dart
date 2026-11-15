const Duration incomingPartyFreshWindow = Duration(minutes: 3);

bool isLiveIncomingCall({
  required String myUid,
  required Map<String, dynamic>? voiceData,
  required bool partyActive,
  required DateTime? partyUpdatedAt,
  required DateTime now,
  Duration freshWindow = incomingPartyFreshWindow,
}) {
  if (voiceData == null) return false;

  final state = voiceData['state'] as String?;
  final callerUid = voiceData['callerUid'] as String?;
  final calleeUid = voiceData['calleeUid'] as String?;

  if (callerUid == null || callerUid == myUid || calleeUid != myUid) {
    return false;
  }
  if (state == 'ended' || state == 'connected') return false;

  if (!partyActive || partyUpdatedAt == null) return false;
  return now.difference(partyUpdatedAt).abs() <= freshWindow;
}
