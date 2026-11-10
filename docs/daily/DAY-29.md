# Day 29 — Three features merged, and a release that was nine commits short

**Date:** 2026-11-10 · **Phase:** 9, the v1.1 backlog · **Roles on point:** Developer, DevOps

## Planned

Merge what was sitting open — #125, #127, #128 — and cut v2.1.0 so the
owner's father gets an APK.

## Delivered

- **#128, #125 and #127 merged**, in that order, with a rebase between each
- **#129**: `tool/release.sh` computes the release boundary from content
- **v2.1.0 released** — tagged, published, APK attached
- The Day 27 log, two days late
- 746 tests

## The release was going to ship without a third of itself

This is the day's finding and everything else is housekeeping.

`tool/release.sh` said **9 commits to replay**. The true figure was **18**.

The script found the previous release by looking for the newest
`chore(release):` commit on `develop`. That marker records where `develop`
was *when somebody remembered to cherry-pick it back* — which is the same
thing as the release only when the cherry-pick was immediate. ADR-015 says to
do it immediately. v2.0.0's was missed, noticed two days later and fixed in
#126, by which time three commits had already landed on `develop`.

So the marker came to rest **above** work that had never been released, and
everything below it looked shipped. `main` confirmed it: no
`identity.dart`, no `ADR-023`, no songbook.

What v2.1.0 would have gone out without:

| | |
|:--|:--|
| `0ed42d9` | the songbook |
| `151a328`, `ec2b5bc` | sign-in, and the Settings row for it |
| `1bf6366` | the Firestore rules fix |
| `13f2053` | the way out of the member sheet — the owner's own request |
| `fc5b8c0` | a bar button a screen reader announced but could not press |
| `e5eddaf`, `3f8c95d`, `c9be706` | the artefact cleanup, the Day 24 log, the v2.0.0 commit |

### Nothing would have failed

The part worth keeping.

The script's own safety check is `git diff develop` on the finished branch.
That compares the replay against `develop` — **not against what was
released** — so it passes whether the commit list was right or wrong. The
changelog is drafted from the same list, so it agrees with itself. And every
test passes on either set, because both sets are internally coherent. The
smaller one is a perfectly good app; it is simply not this one.

Running it would not have helped either. The release would have installed and
worked. The only symptom available was a family opening the app in a
fortnight and finding the songbook gone.

That makes it a **fourth species** of check that cannot do its job, and the
first that neither "break it on purpose" nor "look at the running app"
reaches. Written up in the retrospective, along with what all four have in
common: **every one of them was a check that agreed with itself.** A
tautology agrees by construction, a broken instrument agrees with its own
silence, a test in a fixed-width font agrees with its own apparatus, and a
release script agrees with its own changelog. None had a second, independent
source to disagree with. That is a different question from "can this fail?".

### The fix

Compute the boundary from content: walk `develop`'s own line and find the
newest commit whose tree `main` already has, ignoring `CHANGELOG.md` and
`pubspec.yaml` because the release commit is exactly what differs there. A
tree cannot drift out of step with itself the way a subject line can.

And when nothing matches — `main` holding something `develop` does not, a
hotfix that never came back — it now **refuses** rather than guessing.
Guessing is how this happened.

Verified both ways before being believed: the old logic reports 9 against
this repository and the new one 18; and a throwaway branch built from
`origin/main` with one extra commit makes it exit 1 with the hotfix message
instead of cutting a branch.

## What merging three branches actually cost

`develop` requires branches to be up to date, GitHub's "Update branch" button
is disabled on this repository and merge commits are not allowed. So three
PRs meant three merges and two rebases, each with a full CI run between —
and after #129 was added, four and three.

Worth noting rather than changing. The alternative is letting a branch merge
without having been tested against what it is merging into, which is the
thing that protection exists to prevent. The cost is real and it is the right
cost; it is only annoying because four things were queued at once, which is a
scheduling problem rather than a policy one.

One genuine conflict, three times over: `docs/adr/README.md` gains a row in
each of #125, #127 and #128, and `main`'s index had stopped at ADR-022.
Resolved by keeping 023, 024 and 025 in order. The script aborts on conflict
by design and says to replay by hand, which is what happened.

## Verified

- `git diff develop` on the release branch: **empty**. Only `pubspec.yaml`
  and `CHANGELOG.md` differ, which is the release commit itself.
- 746 tests and `flutter analyze`, green on the release branch rather than on
  `develop` — Day 28's lesson, applied to the thing that actually ships.
- Built and run on the simulator **from the release branch**: launches past
  the splash, This Week shows *Inyathi ibuzwa kwabaphambili* with `isiXhosa`
  beneath it, the Family tab leads with the family and carries the songbook.
- After tagging, the cherry-pick back to `develop` was done **immediately**,
  and the new boundary logic then reports `0 to replay` — `develop` and
  `main` level, which is the state the whole of today was about restoring.

## Open

- **Q5** — nobody fluent has checked the sayings' spelling. Unchanged.
- The navigation bar has now been Family, then Songs, then Family inside one
  day, and carries ADR-016, ADR-020 and ADR-022. Still noticed rather than
  acted on.
- The APK is 54 MB because it carries every ABI. A split would take it to
  roughly 17 MB.
