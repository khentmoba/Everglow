---
name: everglow-release
description: >
  The full procedure for cutting an Everglow release: pick the version, bump
  pubspec.yaml and lib/core/system/app_version.dart together, write Clair's
  CHANGELOG entry, mirror it into README latest-release and history, and
  confirm the release workflow published the tag. Use when releasing,
  versioning, tagging, or syncing version + CHANGELOG + README.
  AGENTS.md keeps only the rule that must never bend.
---

# Everglow release

Releases publish automatically, but ONLY when the version number
changes. The old automation released every deploy with date tags and
cluttered the page, so Khent removed it (see `4b451a2`). The current
`release.yml` workflow is different: it watches `pubspec.yaml` on `main`
and cuts exactly one tag + GitHub Release per version, using the
CHANGELOG entry as the notes. Merges without a version bump do nothing.

Cut a release when user-visible fixes or features have piled up, or when
Khent asks for one. One release PR per version:

1. Pick the next version: patch (`6.1.1`) for fixes, minor (`6.2.0`) for
   features, major (`7.0.0`) for big changes.
2. Bump it in BOTH `pubspec.yaml` (`version: X.Y.Z+N`) and
   `lib/core/system/app_version.dart` (`current`).
3. Add a `## [X.Y.Z] - YYYY-MM-DD - Nickname` section on top of
   `CHANGELOG.md`. Write for Clair: short, warm, grouped by what she
   will notice. The workflow publishes this text as-is, so proofread it.
4. Update `README.md`: the `Latest Release` section mirrors the new
   CHANGELOG entry, and `Release History` gains one linked line
   (`.../releases/tag/vX.Y.Z`). Move the old latest into the history list.
5. Open the release PR. Checks must pass, including the release-sync
   guard (`tool/ci/check_release_sync.dart` fails the PR when the version,
   CHANGELOG, and README disagree).
6. Merge. The release workflow tags the merge commit and publishes the
   GitHub Release by itself — nothing to run by hand.
7. Open the releases page and confirm the new version shows, with the
   README badge following it. If the workflow ever fails, publish by hand
   as fallback: `git tag vX.Y.Z main && git push origin vX.Y.Z`, then
   `gh release create vX.Y.Z --title "vX.Y.Z — Nickname" --notes-file <entry>`.

Rules: never add release steps to `deploy.yml` (releases trigger on
version bumps, not on every deploy). Never date-based tags
(`v2026.06.12` was deleted for this reason). Never move a published
tag — if a release is wrong, cut a new patch version instead.