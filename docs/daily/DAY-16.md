# Day 16 — Clear the decks, and decide the shape

**Date:** 2026-11-01 · **Phase:** 8, v1.1 front end · **Roles on point:** DevOps, Developer

## Planned

Fix #72 so releases can ship again, audit the app, decide the information
architecture. No visual work.

## Delivered

| # | What | Where |
|:--|:--|:--|
| #81 | ADR-015, the release flow without a back-merge | merged |
| #82 | `close-linked-issues` reports failures instead of swallowing them | merged |
| #83 | Android build survives a Maven Central rate limit | merged |
| #84 | The auto-close documentation was false for eight days | merged |
| #85 | ADR-016, four tabs and what goes in each | this one |

Every open defect in the backlog is now closed: #30, #32 and #72.

## One fix immediately exposed another

This is the day's most useful hour, and it was not planned.

#82 made `close-linked-issues.yml` report failures instead of ending each
attempt with `|| true`. The very next merge logged:

```
#30 is already closed — nothing to do.
```

Something had closed it one second before the workflow ran. The timeline
said the actor was the merging account, not `github-actions[bot]` — so
GitHub itself had closed it.

`develop` **is** the default branch, and has been since ADR-007 on Day 7.
GitHub auto-closes linked issues for the default branch. The workflow has
been redundant for eight days, and `WORKFLOW.md` has been telling anybody
who read it the opposite.

**A fix to error reporting found a different bug within sixty seconds**,
which is the most useful thing error reporting ever does. Under the old code
the `|| true` swallowed the signal and nothing was ever learned.

Worth noting how it hid: when ADR-007 moved the default branch, nobody asked
what else depended on it being `main`. The ADR recorded the decision
carefully and said nothing about its consequences elsewhere.

## #72 was three symptoms of one cause

Rebase-merging onto `main` makes copies of every commit; merging `main` back
brings those copies onto `develop` beside the originals.

That is why `develop` holds the whole history twice, why release branches
stopped being mergeable, and why the changelog draft listed seventy commits
for a patch release. Three bugs filed separately across two weeks, one
decision behind all of them.

ADR-015: cherry-pick the release commit onto `develop`, never merge. The
only thing `develop` needs from a release is the version bump and the
changelog entry — the code came from `develop` in the first place.

The script's new boundary uses `--first-parent`, which walks only
`develop`'s own line and so is not confused by the copies. Verified against
the live repository before committing: two commits since v1.0.1, not 148.

## The filter that had to be generous

#83 skips the Android build for documentation-only changes, which removes
the rate-limit exposure entirely for the PRs most likely to hit it.

#30 flagged the risk when it was filed: *"path filters that are too broad
would stop guarding real changes"*. So the filter builds for anything
outside `docs/`, the issue templates, README and CHANGELOG, and it was
tested against nine change sets — including the two a careless version gets
wrong: a PR touching **both** docs and `lib/`, and a file called `docs.md`
that is not inside `docs/`.

My first test harness reported two of those wrong. The harness was broken,
not the filter, and finding out which took re-running it from a file under
`bash`. Worth the five minutes: shipping a filter I believed was broken
would have meant weakening it for no reason.

## The shape of v1.1

ADR-016 decides the information architecture before any visual work starts,
which is the whole point of today having no visual work in it.

Four tabs — This week, Weeks ahead, Journal, Settings. Setup stays a
first-run flow rather than becoming a destination. The version line moves
off This Week into Settings, giving Day 8's "this screen answers one
question" back some of its meaning.

Settings absorbs the things that currently have no home: the duplicated
"which one are you?", the reminders switch, the family (#74), the turnover
day, and appearance.

## Tomorrow

Day 17 — the design system. Type scale, spacing, components, contrast and
dark mode, as tokens rather than screens, so that Day 21's restyle is
mechanical.
