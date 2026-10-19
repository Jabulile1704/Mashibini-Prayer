# Day 1 — Inception

**Date:** 2026-10-19 · **Phase:** 1, inception and planning · **Roles on point:** PM, PO, DevOps

## Planned

Charter, requirements baseline, backlog, project board, branch protection, CI
skeleton, app scaffold.

## Delivered

| # | What | Where |
|:--|:--|:--|
| #1 | Charter, requirements baseline, branching model, 14-day plan, issue and PR templates, PR hygiene checks | merged to `develop` |
| #24 | Flutter scaffold, strict analyser, three widget tests, CI pipeline, Dependabot | merged to `develop` |
| — | 22 backlog items created,traced to a requirement ID, on the board and in five milestones | board + issues |
| — | `main` and `develop` protected: PR required, CI required, no force pushes | repo settings |

Both merges were squashed into `develop` through a reviewed pull request. No
commit was made directly to a protected branch.

## Decisions

1. **The pipeline arrives with the thing it builds.** The CI workflow was held
   back from #1 and shipped in #24 alongside the scaffold, so the first run of
   the pipeline was green for a real reason rather than skipped for want of a
   `pubspec.yaml`.
2. **Flutter is pinned to 3.47.4**, not floating on `stable`. A build that
   passed yesterday should pass today for the same reasons.
3. **The analyser is stricter than the Flutter default.** Strict casts,
   inference and raw types, plus `unawaited_futures` and `cancel_subscriptions`
   — the two mistakes this app will be able to make once the rota listens to a
   stream.
4. **Scope is fixed on the rota.** The verse and the journal are explicitly
   secondary, and five tempting features are named as out of scope so that
   adding one later has to be a decision rather than a drift.

5. **Issues are closed by a workflow, not by GitHub.** Merging #24 showed that
   GitHub only auto-closes a linked issue when the PR merges into the *default*
   branch, and everything here merges into `develop`. Rather than close the
   backlog by hand for a fortnight — which would have held until the first day
   somebody forgot — `.github/workflows/close-linked-issues.yml` now reads the
   `Closes #n` keywords out of a merged PR and closes them. Found on Day 1
   because the first merge was checked rather than assumed.

## Open questions raised

| # | Question | Owner | Blocks |
|:--|:--|:--|:--|
| Q1 | Which weekday does the family's week actually turn over on? | Stakeholder | Day 6 |
| Q2 | Which Bible translation may be bundled and redistributed? | PO + Dev | Day 9 |
| Q3 | Individual sign-in, or one shared family install? | PO | Day 7 |
| Q4 | Should the journal ever be shareable by choice? | PO | post-v1 |

Q1 and Q3 need a real answer from the family, not a persona's guess. Both are
asked early enough that Day 6 and Day 7 are not at risk yet.

## Blocked

Nothing.

## Tomorrow — Day 2, design

Architecture, the data model and ERD, the Firestore collection layout, and
ADRs 1–3. Issue #19.
