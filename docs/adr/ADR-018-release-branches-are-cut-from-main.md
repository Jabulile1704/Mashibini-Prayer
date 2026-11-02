# ADR-018 — Release branches are cut from `main`

**Status:** Accepted · **Date:** 2026-11-02 · **Deciders:** Owner, DevOps
**Supersedes:** the branching half of
[ADR-015](ADR-015-releases-cherry-pick-back-to-develop.md)

## Context

ADR-015 stopped back-merging `main` into `develop`, on the reasoning that
the merge commit was what made release branches unrebaseable. The reasoning
was right. The fix was **insufficient**, and ADR-015 said the opposite of
what was true about the alternative:

> **Cut release branches from `main` instead of `develop`.** What was done
> by hand for v1.0.1. Rejected as the standing process: the release would
> then have to pull `develop`'s work across by cherry-pick anyway, which is
> the same work in the harder direction.

That was wrong twice over. It is not the harder direction — it is the only
direction that works — and "the same work" ignores that one version is done
by a script and the other by a person at eleven at night.

## What ADR-015 missed

The two back-merges already made — `2225ec6` (v1.0.0) and `4950f7b`
(v1.0.1) — are in `develop`'s history **permanently**. Not making new ones
does not remove the old ones, so every branch cut from `develop` still
carries a merge commit and GitHub still refuses to rebase it.

Both v1.1.0 and v1.2.0 were refused and rebuilt by hand. Two releases, the
same manual recovery, after an ADR that was supposed to have fixed it.

## Decision

**`tool/release.sh` cuts the release branch from `origin/main` and replays
`develop`'s work onto it.**

That is exactly what the hand-rebuild did, twice. It is now in the script
rather than in somebody's memory.

```
git checkout -b release/vX.Y.Z origin/main
git cherry-pick <every non-merge commit on develop since the last release>
```

### The invariant that makes it safe

After replaying, the script asserts:

```
git diff develop --stat    # must be empty
```

The release branch must hold **exactly** `develop`'s code. If a commit were
missed the release would quietly ship something other than what was tested,
and that is the one failure mode a release script must not have. The script
refuses to continue rather than producing a plausible-looking branch.

A failed cherry-pick aborts, deletes the branch and says what to check —
most likely a hotfix that landed on `main` and never came back.

### The changelog comes from the replayed set

`$PREVIOUS` is a commit on `develop`, and the branch is now cut from `main`,
so `$PREVIOUS..HEAD` is not a range that means anything — it would list the
whole project, which is #70 reappearing from the other side. The changelog
is generated from the list of commits that were actually replayed.

## Alternatives considered

**Allow merge commits on `main`.** A settings change, no script work, and
genuinely defensible: `main`'s "linear history" is already a chain of
rebased copies that share no ancestry with the branch they came from, so the
rule protects something not quite real.

Not chosen, for two reasons. It weakens a protection the owner set
deliberately, and it fixes only the symptom — `develop` would keep
accumulating duplicated history, and the changelog boundary would still need
the `--first-parent` trick. Cutting from `main` leaves both branches clean.

**Rewriting `develop` to remove the two merges.** A force push over
published history. Still not worth it; still documented in RETROSPECTIVE.md.

## Consequences

**Releasing is one command again**, and the command is the one that was
already being run by hand.

**The script can now fail in a new way** — a cherry-pick conflict, when
`main` has something `develop` does not. That is a real situation (a
hotfix), it says so plainly, and leaving the repository on `develop` with no
stray branch is part of the fix.

**ADR-015's other half stands.** The release commit still goes back to
`develop` as a cherry-pick, never a merge. That is what stops the problem
growing; this is what stops it blocking.
