# One-time welcome gift

Clair's normal sign-in can display a private, self-contained HTML gift before
she continues into Everglow. Other profiles and agent sessions skip the check.
There are no new passwords, dependencies, routes, or Firestore rules.

The content lives in her existing recipient-owned document:
`users/{uid}/progress/welcome_gift`. The public repository and PR screenshots
must contain synthetic content only.

| Field | Meaning |
| --- | --- |
| `enabled` | Only `true` allows the gift to appear. |
| `html` | The private, self-contained document, up to 500,000 characters. |
| `completedAt` | Absent or null until she chooses **Continue to Everglow**. |

Prepare the document with `enabled: false`, review the gift, deploy the frontend,
then enable it when the sender is ready for delivery. Do not clear an existing
receipt or overwrite another active gift without the sender's instruction.

Completion writes a server timestamp to `completedAt`. Every fresh signed-in
session reads from the server, so another phone or tablet skips a completed
gift. Closing before Continue leaves it available. A failed read opens the app
normally and tries again on a later session; a failed completion keeps the gift
open with a retry message. Offline opening does not consume the gift.

The existing sandboxed HTML viewer keeps the document isolated from app state.
Continue belongs to Flutter, so the HTML has no bridge to account data.

For a synthetic local preview:

```sh
flutter run -d chrome -t tool/welcome_gift_preview.dart
```

The harness can simulate another visit after completion or reset its in-memory
demo receipt. It never reads or changes a real account.
