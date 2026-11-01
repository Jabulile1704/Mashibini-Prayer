# ADR-015 — The release goes back to `develop` as a cherry-pick, not a merge

**Status:** Accepted · **Date:** 2026-11-01 · **Deciders:** Owner, DevOps
**Supersedes:** part of [ADR-007](ADR-007-develop-is-default-and-prs-rebase.md)

## Context

ADR-007 chose two rules on Day 7: every pull request **rebases**, so `main`
and `develop` keep a linear history; and Git Flow's **back-merge** returns
the release to `develop` with a merge commit, because a release is a join of
two histories.

Both rules are individually reasonable. Together they do not work, and it
took two releases to find out.

## What actually happened

**`develop` ended up holding the entire history twice.** 148 commits, 76
unique subjects, **72 of them duplicated**. Rebasing a release branch onto
`main` creates copies with new hashes; merging `main` back brings those
copies onto `develop` beside the originals.

**Release branches stopped being mergeable** (#72). A branch cut from
`develop` carries the back-merge commit, and GitHub refuses to rebase a
branch containing a merge:

```
GraphQL: This branch can't be rebased (mergePullRequest)
```

v1.0.1 shipped only because the release was rebuilt by hand on a branch cut
from `main`. Every release after it would have needed the same improvisation.

**The changelog boundary stopped being computable from the tag.** Because
`main`'s commits are copies, `git log v1.0.0..develop` shares no ancestry to
subtract and returns everything — which is how `tool/release.sh` came to
offer seventy commits as the changelog for a patch release (#70).

Three symptoms, one cause.

## Decision

**After tagging, the release commit is cherry-picked onto `develop`. `main`
is never merged back.**

```
git checkout develop
git cherry-pick <the chore(release) commit>
git push
```

The only thing `develop` actually needs from a release is the version bump
and the changelog entry — one commit. The code is already there; it came
from `develop` in the first place.

### What this buys

- **`develop` stays linear**, so every branch cut from it can be rebased, so
  every release can be merged.
- **The duplication stops growing.** One commit per release instead of a
  merge that drags a rewritten copy of everything behind it.
- **The changelog boundary becomes computable again.** The cherry-picked
  `chore(release): vX.Y.Z` sits on `develop`'s own first-parent line, so
  `git log <it>..HEAD` is exactly the work since the last release.

### What it costs

**`develop` no longer records that a release happened as a merge.** It
records it as a commit, which is a weaker statement about history but a true
one — and the tag on `main` is where a release is actually recorded.

**A release fix made on the release branch has to be cherry-picked too.** In
practice there is at most one of those per release, and forgetting it shows
up immediately as the fix being absent from `develop`.

## The 72 commits already duplicated

**Left alone.** Removing them means rewriting `develop`'s published history
and force-pushing over it. That is a much larger and more dangerous
operation than the problem justifies on a repository whose history is also
the record of a learning exercise.

They are documented in RETROSPECTIVE.md. New ones stop appearing from this
release onward.

## Alternatives considered

**Allow merge commits on `main`.** Simplest, and honest about what a release
is. Rejected because it abandons the linear history ADR-007 chose rather
than fixing the thing that prevented it, and does nothing about the
duplication.

**Squash-merge releases into `main`.** Squash is disabled repository-wide
(ADR-007) for good reasons that have not changed.

**Cut release branches from `main` instead of `develop`.** What was done by
hand for v1.0.1. Rejected as the standing process: the release would then
have to pull `develop`'s work across by cherry-pick anyway, which is the
same work in the harder direction.
