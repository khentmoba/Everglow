---
name: everglow-release
description: >
  The file-level steps to cut an Everglow release: bump the version in
  pubspec.yaml and lib/core/system/app_version.dart together, add Clair's
  CHANGELOG entry, mirror it into README latest-release and release history,
  and confirm the workflow published the tag. Use when releasing, versioning,
  tagging, or syncing version + CHANGELOG + README. AGENTS.md holds the
  rules; this is only the runbook.
---

# Everglow release runbook

**Rules live in AGENTS.md, `## Releases`.** If the two ever disagree,
AGENTS.md wins. This file is just the paths and the order.

`release.yml` watches `pubspec.yaml` on `main` and cuts exactly one tag +
GitHub Release per version, publishing the CHANGELOG entry as the notes. A
merge with no version bump does nothing at all.

## 1. Pick the version and bump both places

Patch `X.Y.Z+1` for fixes, minor for features, major for big changes.

- `pubspec.yaml` -> `version:`
- `lib/core/system/app_version.dart` -> `current`

Both, or the release-sync guard fails the PR.

## 2. Write Clair's CHANGELOG entry

Top of `CHANGELOG.md`:

```
## [X.Y.Z] - YYYY-MM-DD - Nickname
```

Short, warm, grouped by what she will notice. The workflow publishes this
text verbatim as the release notes, so proofread it.

## 3. Mirror it in README

- `Latest Release` = the new entry.
- `Release History` = one linked line `.../releases/tag/vX.Y.Z`; the old
  latest moves down into the list.

## 4. Check, PR, merge

```
dart tool/ci/check_release_sync.dart
git checkout -b release/vX.Y.Z main
git push -u origin release/vX.Y.Z
gh pr create --base main --title "release: vX.Y.Z — Nickname" --body-file <body>
```

The workflow tags the merge commit itself. Nothing to run by hand.

## 5. Confirm it published

Open the releases page: the version shows and the README badge follows it.

Workflow failed? Fallback, by hand:

```
git tag vX.Y.Z main && git push origin vX.Y.Z
gh release create vX.Y.Z --title "vX.Y.Z — Nickname" --notes-file <entry>
```

Never move a tag that is already published. Cut a new patch instead.