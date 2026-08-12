/// How stale a watch-party room can be before its voice room is
/// treated as an orphan. The host heartbeats every 5s while the
/// party is actually live, so anything older than this was left
/// behind by a closed tab or a party that ended without cleanup.
const Duration incomingPartyFreshWindow = Duration(minutes: 3);

/// Pure decision helper for the app-wide "partner started a watch
/// party" banner.
///
/// The `voice_rooms` doc can be left in `calling` by a closed tab or
/// an old session, so the banner must not trust it alone. It should
/// only surface while the matching `watch_party_rooms` doc is still
/// active and was recently updated by the host's heartbeat.
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
