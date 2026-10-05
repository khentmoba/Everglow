<!-- What did you change, in one or two plain sentences? -->
## What

## Why it matters for Clair

<!-- Paste screenshot(s) of the changed screen here (just what changed).
     Frontend preview links are posted by Quality using its verified web artifact.
     Docs/backend-only PRs can mark preview N/A.
     Repo is public: for couple-only screens (chat, gallery, notes,
     garden, AI memories) use FAKE demo data only — never real couple data.
     Save shots in docs/pr-proof/pr-<number>/ on your branch and embed them:
     ![what changed](https://raw.githubusercontent.com/khentmoba/Everglow/<commit-sha>/docs/pr-proof/pr-<number>/shot.png)
     Pin to the commit SHA (not the branch name) so pictures survive after merge. -->
## Proof

- [ ] Screenshot shows above (or N/A for non-UI changes like CI/docs)
- [ ] Preview link checked on phone width (or N/A for non-UI changes)

## Checks

- [ ] `flutter analyze` passes
- [ ] `flutter test --exclude-tags="golden,network"` passes
- [ ] Regression guards pass (`dart tool/ci/check_*.dart`)
- [ ] Looked at the change in Chrome (`flutter run -d chrome`), or N/A for non-UI changes
- [ ] Relevant manual browser tooling checks recorded (see AGENTS.md), or N/A
