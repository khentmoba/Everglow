# PR proof screenshots

Pictures attached to PRs live here so they show inline in the
conversation and keep working after the branch is merged and deleted.

- One folder per PR: `docs/pr-proof/pr-<number>/`
- Couple-only screens (chat, gallery, notes, garden, AI memories):
  FAKE demo data only. The repo is public — never real couple data.
- Keep shots small: phone width (~430px), compressed. One or two per PR.
- Embed in the PR body with a raw URL pinned to the commit SHA
  (not the branch name — branches get deleted):

`![what changed](https://raw.githubusercontent.com/khentmoba/Everglow/<sha>/docs/pr-proof/pr-<number>/shot.png)`

Non-UI changes (CI, docs, backend-only): a picture of the preview
booting logged-out is nice, otherwise honestly mark N/A.
