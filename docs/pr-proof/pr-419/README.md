# Nine-issue audit fixes — verification

All screenshots contain synthetic demo words. No private account was used.

## Browser steps (Chrome)

1. Open the real journal dialog with a network-free Firestore boundary that rejects writes.
2. At a 430 × 932 phone viewport, click Save Entry.
3. Confirm the dialog stays open, demo words remain, the inline error is visible, and Save Entry remains available.
4. Click Save Entry again; confirm another failed attempt leaves the same words intact.
5. Repeat the layout check at an 820 × 1180 tablet viewport. No new browser errors after a clean restart.

Screenshots are cropped to the changed dialog. The temporary demo entry point was removed before the release build.

## Regression checks

- Native Firestore and Storage emulator requests prove cinema users cannot claim a couple username, read couple notes/images, or use a forged legacy profile. Existing signed couple identities still work, including profile repair.
- Server tests cover strict Storage URL/bucket validation, redirect rejection, forwarded-IP prefix spoofing, signed identity resolution, and refusal to fall back to client-supplied Motchi identity.
- Flutter tests cover device-local offline verification; failed journal/calendar writes; retained journal drafts and retry; atomic poll finalization; all-day events; recurring dates; month ends and leap years.
- Server calendar tests cover the same recurrence/all-day behavior in Motchi reads and nudges, in Philippine wall time.
- Existing cinema boundary tests from PR #416 cover findings 8 and 9, already fixed on main before this branch.

## Limits

The emulator and synthetic browser checks do not prove a production deployment. Passcodes remain unchanged. Old downloaded builds cannot be recalled; rotating previously exposed codes requires a separate explicit decision. A device must complete an online login once to create its new offline verifier.
