---
name: everglow-release
description: >
  Cut an Everglow release: pick the version, bump react/package.json and
  functions/common.js together, write Clair's CHANGELOG entry, mirror it into
  README, and confirm the release workflow published the tag. Use when
  releasing, versioning, tagging, or syncing version + CHANGELOG + README.
---

# Everglow release

`.github/workflows/release.yml` watches `react/package.json` on `main` and
cuts one tag + GitHub Release per version, using the CHANGELOG entry as the
notes. Merges without a version bump publish nothing. (An older automation
released every deploy with date tags and cluttered the page; Khent removed
it in `4b451a2`.)

Cut a release when user-visible fixes or features have piled up, or when
Khent asks. One release PR per version:

1. Pick the next version: patch (`6.3.1`) for fixes, minor (`6.4.0`) for
   features, major (`7.0.0`) for big changes.
2. Bump it in `react/package.json` (`version`, also `npm --prefix react
   install --package-lock-only` so the lockfile follows) and in
   `functions/common.js` (`APP_VERSION = 'X.Y.Z+1'`, which `/api/health`
   reports).
3. Add a `## [X.Y.Z] - YYYY-MM-DD - Nickname` section on top of
   `CHANGELOG.md`. Write for Clair: short, warm, grouped by what she will
   notice. The workflow publishes this text as-is, so proofread it.
4. Update `README.md`: `Latest Release` mirrors the new CHANGELOG entry and
   must contain `vX.Y.Z`; `Release History` gains one linked line
   (`.../releases/tag/vX.Y.Z`).
5. Open the release PR through `everglow-pr`. The release check in
   `tool/ci/run_checks.mjs` fails it when `react/package.json`, the newest
   CHANGELOG entry, and README disagree.
6. After Khent merges, the workflow tags the merge commit and publishes the
   GitHub Release by itself.
7. Open the releases page and confirm the new version shows, with the README
   badge following it. If the workflow fails, publish by hand:
   `git tag vX.Y.Z main && git push origin vX.Y.Z`, then
   `gh release create vX.Y.Z --title "vX.Y.Z — Nickname" --notes-file <entry>`.

Releases trigger on version bumps only, so release steps stay out of
`deploy.yml`. Tags are always `vX.Y.Z` (the date tag `v2026.06.12` was deleted
for this reason). A published tag is permanent: fix a wrong release with a new
patch version.
