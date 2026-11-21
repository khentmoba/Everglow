---
name: everglow-release
description: >
  Cut and announce an Everglow release: bump version files, write Clair's
  CHANGELOG and README entries, ship the release PR, verify the GitHub Release,
  and post the Discord update. Use when releasing, versioning, syncing release
  files, or announcing an Everglow release on Discord.
---

# Everglow release

`.github/workflows/release.yml` watches `react/package.json` on `main` and cuts
one `vX.Y.Z` tag + GitHub Release per version from the top `CHANGELOG.md` entry.
Merges without a version bump publish nothing.

## Steps

Cut a release when user-visible fixes or features have piled up, or when Khent
asks. One release PR per version:

1. **Pick the version:** patch (`6.4.1`) for fixes, minor (`6.5.0`) for
   features, major (`7.0.0`) for big changes.
2. **Bump version sources together:** update `version` in `react/package.json`,
   run `npm --prefix react install --package-lock-only` so
   `react/package-lock.json` follows, and set `APP_VERSION = 'X.Y.Z+1'` in
   `functions/common.js`.
3. **Write `CHANGELOG.md`:** add `## [X.Y.Z] - YYYY-MM-DD - Nickname` at the
   top. Write for Clair: short, warm, grouped by what she will notice. The
   workflow publishes this entry as-is, so proofread it.
4. **Mirror into `README.md`:** update `Latest Release` to match the new
   CHANGELOG entry (must include `vX.Y.Z`) and add one linked line under
   `Release History` (`.../releases/tag/vX.Y.Z`).
5. **Ship the release PR** through `everglow-pr`. `node tool/ci/run_checks.mjs`
   verifies `react/package.json`, `CHANGELOG.md`, `README.md`, and
   `functions/common.js` agree.
6. **Confirm the GitHub Release** after merge: check that `vX.Y.Z` tags the
   merge commit, the GitHub Release is published, and the README badge updates.
   If the workflow fails, publish by hand:
   `git tag vX.Y.Z main && git push origin vX.Y.Z`, then
   `gh release create vX.Y.Z --title "vX.Y.Z — Nickname" --notes-file <entry>`.
7. **Post the Discord announcement** using the rules below.

## Discord announcement

Everglow overrides the generic embed, GitHub link, and `Automated Release System`
footer from `discord-notify-and-release`. Every Everglow announcement uses this
exact style:

- **Channel:** `#everglow-release` in the Felary server (channel ID
  `1561735506717573210`).
- **Webhook & avatar:** Post through the persistent `Everglow Release` webhook
  (ID `1573786061044195468`) with `username: "Everglow Release"` and the
  Everglow cat logo avatar
  `https://raw.githubusercontent.com/khentmoba/Everglow/main/assets/images/logo.jpg`
  set on both the webhook (`avatar`) and the send call (`avatarURL`). Leave the
  webhook in place for future releases. If the current tool cannot read the
  existing webhook's token, create a fresh `Everglow Release` webhook with that
  `avatar`, send through it, and keep it in place. Post only through the
  webhook, never as the plain bot user, and keep webhook tokens out of git,
  logs, and replies.
- **Message format:** carry only the live site URL and summarized `- ` bullets
  (no GitHub link, no automated footer):

```markdown
New Release: **Everglow Web vX.Y.Z** is now live! The website updates automatically in the cloud.

Live site: https://everglow-1c6db.web.app

- <short plain-English summary covering every change in the release>
```

- **Bullets:** Summarize **every** change from the `CHANGELOG.md` entry into
  concise `- ` bullets, with one short plain-English line per feature or change
  group, covering all sections without dropping smaller touches.

## Guardrails

- Tags are always `vX.Y.Z` and trigger on version bumps only; keep release steps
  out of `deploy.yml`.
- A published tag is permanent: fix a wrong release with a new patch version.
- A notification-only request updates or sends the Discord post for the existing
  release without bumping versions, editing release files, or re-tagging.

## Done when

- `node tool/ci/run_checks.mjs` passes with `react/package.json`,
  `CHANGELOG.md`, `README.md`, and `functions/common.js` synced at `vX.Y.Z`.
- Tag `vX.Y.Z` and its GitHub Release are live on the merge commit.
- One `Everglow Release` webhook post with the Everglow cat logo avatar is live
  in `#everglow-release`, carrying only the live site URL and summarized `- `
  bullets covering every change in the release.
