/// Maps a couple username (`khentsgdz` / `clairjassen`) to the
/// partner's display name, uppercased for use as a [PartnerSubrow]
/// eyebrow. Returns `"PARTNER"` as a safe fallback for any other
/// signed-in account — the caller is expected to gate the partner
/// sub-row on `AuthService.isCoupleUser` so the fallback is only ever
/// shown in tests / unexpected states.
String partnerEyebrowLabelFor(String userName) {
  if (userName == 'clairjassen') return 'KHENT';
  if (userName == 'khentsgdz') return 'CLAIR';
  return 'PARTNER';
}
