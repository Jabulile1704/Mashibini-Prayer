# Day 14 — Release v1.0.0

**Date:** 2026-10-30 · **Phase:** 6, deployment · **Roles on point:** DevOps

## Planned

Release branch, version bump, changelog, build, tag `v1.0.0` (#22).

## Delivered

| # | What | Where |
|:--|:--|:--|
| #64 | `release.yml`, `tool/release.sh`, RELEASING.md, ADR-013, the version shown in the app | merged to `develop` |
| #65 | `CHANGELOG.md`, version `1.0.0+2` | merged to `main` |
| — | Tag `v1.0.0`, GitHub Release with the APK, `main` merged back into `develop` | published |

405 tests, analyzer clean. Installed on the owner's iPhone as 1.0.0 (2).

## The brief changed, and the work changed with it

The plan said "release v1.0.0". The owner said they intend to keep shipping
to four phones, often.

Those are different jobs. Cutting one release is an afternoon of careful
commands. Making release *fifteen* as cheap as release one is a workflow, a
script and a page of documentation — and only the second one is worth
anything by Day 20.

So the day's output is mostly machinery, and v1.0.0 is the thing that proves
the machinery works.

## A release is a tag, and nothing else is

`release.yml` fires on `v*`. There is no `workflow_dispatch`, so nothing can
be published that was not tagged. It does not fire on push to `main`, so a
merge is not the decision — the tag is.

It refuses to publish when the tag disagrees with `pubspec.yaml`, or when
`CHANGELOG.md` has no section for that version.

The first check is not ceremony. A mismatched tag ships a build whose own
version line contradicts the release it came from, and the only place that
surfaces is somebody's phone, weeks later, while trying to work out which
build has the bug. The second makes the changelog an **input** rather than an
output: a version with nothing worth writing down did not need cutting.

## The script does not make decisions

`tool/release.sh` does the parts that get forgotten at 11pm — the branch, the
version, the build number, the changelog heading. It does not tag and it does
not push.

That is deliberate. Tagging is a decision, and a script that makes decisions
on somebody's behalf is a script somebody eventually runs by accident.

It drafts the changelog from Conventional Commit subjects and then prints, in
as many words, an instruction to go and rewrite it. That instruction was
followed: the draft said *"feat(rota): pass over a turn, and put it back"*
and the entry says *"Skip somebody's week when they are away. The week passes
to the next person and everyone moves up; nobody is owed a double turn
later."*

A commit subject is written for a reviewer. A changelog entry is written for
the family.

## The script's own instructions had a bug in them

`tool/release.sh` printed `git commit -am` as the next step. On a *first*
release `CHANGELOG.md` does not exist yet, and `-am` stages tracked files
only — so the release commit contained the version bump and nothing else.

Found by running `git show --stat` instead of assuming the commit held what
had just been written. That is the Day 11 lesson, applied: **check what you
committed, not what you meant to commit.**

Worth noticing where it came from. The instruction was written while thinking
about the *steady state*, where CHANGELOG.md is tracked and `-am` works
perfectly. The bug only exists on the first run — rare enough to forget,
common enough to happen again the next time somebody starts a changelog from
nothing.

## The app knows which build it is

At the foot of the home screen, in the quietest type the theme has.

This is the thing that makes frequent shipping survivable. When something is
wrong the first question is whether the fix is even installed, and until
today that needed a cable and a Mac. Day 8 designed the home screen to answer
one question and a version string is not it — so it sits at the bottom of the
scroll, where somebody looking for it finds it and nobody else notices.

The build number climbs forever and never repeats, across any version. Two
builds sharing a number are indistinguishable on a phone, which is the one
thing a build number exists to prevent. v1.0.0 is build **2**, not build 1,
because 0.1.0 already used 1.

## Not signed, and ADR-013 says why

"Signed build" is in #22's acceptance criteria and is not done.

There is no App Store, no TestFlight, no paid Apple account, and four users in
one house. A key generated in CI would produce something that *looks* like
provenance and carries none: the key would live in the workflow run, nobody
would hold the counterpart, no installer would check it. That is worse than
plainly unsigned, because it invites the belief that the build was verified.

The criterion is unmet on purpose, with the reasoning written where somebody
will find it rather than buried in a commit message. What would change it: a
paid membership, or anyone outside the house installing the app.

ADR-013 also records that **a free Apple account signs for seven days**, after
which the iPhone build stops opening until it is installed again. That is
Apple's rule and the app can do nothing about it — it is in RELEASING.md so
the next person does not file it as a bug.

## One correction

Pushing the back-merge to `develop` printed `3 of 6 required status checks
have not succeeded`, and I said the push had been refused. It had not — that
was a warning and the merge commit was already on the remote. Checked against
`origin/develop` rather than against the message, which is the same rule
ADR-007 recorded after Day 7: **check twice, with a gap, before writing down
what a remote system did.**

The back-merge is the one merge in this repository that is not a rebase.
ADR-007 makes every pull request rebase; a release is a join of two histories
and the merge commit is the record of it.

## Still open

- **Firestore sync is unwired.** Named as a known limit in the changelog
  rather than left to be discovered. Still the owner's decision for v1.1.
- The rules need deploying: `firebase deploy --only firestore:rules`.
- The two `Mashibini.Prayer` app registrations in the console are unusable.

## Tomorrow

Day 15 — retrospective, metrics, and the v1.1 backlog.
