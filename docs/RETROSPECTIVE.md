# Retrospective — v1.0.1

**Date:** 2026-11-01 · **Covers:** Days 1–15 · **Written by:** PM, with QA and
DevOps notes

Fifteen planned days, twelve of them with commits, one app on two phones. This
is what the numbers say, what the exercise actually bought, and what is wrong
with the way it was run.

## The numbers

Measured, not recalled. Every figure here came from the repository on the day
this was written.

| | |
|:--|--:|
| Requirements baselined | 16 functional, 7 non-functional |
| Requirements delivered in full | 15 of 16 |
| Tests | 405 |
| Line coverage | 98.8% (1445 / 1463) |
| Source | 4,922 lines across 49 files |
| Test code | 6,070 lines across 33 files |
| Pull requests merged | 40 |
| Pull requests closed unmerged | 1 |
| Issues opened | 32 |
| Issues closed | 28 |
| ADRs | 14 |
| Documentation | ~29,700 words |
| Releases | 2 (v1.0.0, v1.0.1) |

**More test code than source code.** That was not a target; it is what
happens when the acceptance criteria are written first and every bug gets a
test before it gets a fix.

### Against the charter

| | Criterion | Status |
|:--|:--|:--|
| S1 | The family stops asking whose turn it is | **Not yet measurable.** Two phones have the app; a full cycle has not passed |
| S2 | The handover is never missed | **Partially.** Each phone can remind its own owner (R5.1). Nothing reminds the family collectively — ADR-010 |
| S3 | It works without a signal | **Met.** Everything reads from the phone; nothing waits on a network |
| S4 | It survives being left alone | **Met.** The rota is derived from an anchor, so a week away costs nothing (ADR-002) |

S1 is the only criterion that matters and the only one that cannot be
checked yet. That is the honest state of this project: it is built, it is
not yet proven useful.

## What the method actually bought

### The ADRs paid for themselves, twice, measurably

**ADR-010** (the free tier is a design constraint) was written on Day 11. On
Day 12 the handover-reminder story turned out to be unbuildable as written —
sending a push needs a server and Spark has nowhere to run one. Because the
limit was already written down, Day 12 was spent building the achievable half
rather than discovering halfway through that the other half was impossible.

**ADR-008** (merging is a union of append-only logs) was written on Day 7 and
forced ADR-012 on Day 13. Undo for a skipped turn looked like a one-line
delete, and ADR-008 is what made it obvious that a delete would be silently
reversed by the first sync. Nothing else in the codebase would have caught
it: sync is not wired, so the bug would have worked perfectly until the day
it did not.

Two ADRs out of fourteen directly changed what got built. The other twelve
are insurance.

### The board and the issue tracker were mostly ceremony

Honest assessment: for a single developer, moving a card from Todo to In
Progress to Done added nothing that the branch name did not already say.

Where it earned its place was **after** a bug: `Closes #n` means a defect
leaves a trace that outlives the branch it was fixed on. Five defects were
filed and fixed this fortnight, and each one is now findable by somebody who
asks "has this gone wrong before?" — which is the only question an issue
tracker answers well.

The PR hygiene check caught me three times, including on Day 14 when I
labelled a PR `type:defect` without filing the issue. That is the rule
working on its author.

### Conventional Commits earned their place late

For thirteen days they were a formatting rule. On Day 14 they became the
changelog, and `tool/release.sh` generates a draft that is 80% usable. The
other 20% is the part that matters — *"feat(rota): pass over a turn"* has to
become *"Skip somebody's week when they are away"* — and no tool will do
that.

## What went wrong

### Eight bugs were found by using the app, not by testing it

This is the single clearest finding of the fortnight.

| Day | Bug | Why no test caught it |
|:--:|:--|:--|
| 12 | Reminders switched on but scheduled nothing | Every test set `youAre` first, because every test was written by somebody who knew the field existed |
| 13 | Every button on the schedule screen died after one tap | The test binding answers the accessibility channel instantly; a real phone with no screen reader never answers it |
| 13 | The Journal's empty state overflowed at the largest text size | The sweep seeded data before pumping, so it never rendered an empty state |
| 13 | A name broke mid-word: "Jabuli / le" | Nothing overflowed. It was only ugly |
| 14 | `git commit -am` silently dropped the changelog | The instruction was written for the steady state, where the file is already tracked |
| 14 | Every release was signed with a different key | Only breaks on the *second* install |
| 14 | The changelog draft listed all 70 commits | Only wrong on the *second* release |
| 14 | A tag was pushed onto the wrong commit | `gh pr merge` failed inside a pipe; `$?` reported `tail` |

405 tests and 98.8% coverage did not prevent any of them.

The pattern is not "write more tests". It is that **a test asserts what
somebody thought to assert**, and four of these eight only exist on the
*second* run of something — a second install, a second release, a second
person. The first pass of anything is the pass where the bug is invisible.

What worked instead: opening the app on a simulator at a setting I do not
use, and running the release script twice.

### The git workflow is wrong, and it took two releases to show

Rebase-merging into `main` and then merging `main` back into `develop` is a
combination that does not work. Two consequences, both discovered by doing it
rather than by reasoning about it:

**`develop` now contains the entire history twice.** 148 commits, 76 unique
subjects, 72 of them duplicated. Rebasing onto `main` makes copies with new
hashes; the back-merge brings those copies onto `develop` alongside the
originals.

**Release branches cannot be merged at all** (#72). A branch cut from
`develop` carries the back-merge commit, and GitHub refuses to rebase a
branch containing a merge. v1.0.1 shipped only because the release was
rebuilt by hand on a branch cut from `main`.

ADR-007 chose rebase-only for a linear history and got the opposite. The fix
is a Day 16 decision, not a patch — it changes a documented rule.

### "Two weeks of consistent contributions" was met in spirit, not in shape

The brief asked for consistency. The repository shows commits on **12 days**,
from 19 to 30 October, with **24 October missing entirely**. Days 6 and 7 landed
in one sitting, and 29 commits landed on the final day.

The daily logs tell the same story more honestly than the graph does: this
was worked in bursts of several hours, not in a steady hour a day. That is
worth stating plainly rather than letting the contribution graph imply a
discipline that was not there.

## What I would do differently

1. **Use the thing on a device every day**, not at the end of a story. Four of
   the eight bugs above were visible within a minute of opening the app.
2. **Run every script twice before trusting it.** Three Day-14 bugs existed
   only on the second run.
3. **Decide the git workflow by trying a release on Day 1**, not by reasoning
   about it on Day 2 and discovering on Day 14 that it cannot work.
4. **Stop writing tests at about 90% coverage** and spend the remainder on
   using the app. The last 9% of coverage caught nothing that mattered; an
   hour at the largest accessibility text size caught three real bugs.
5. **Get the family onto it sooner.** The Product Owner persona made every
   product decision for fifteen days. S1 is still unmeasurable because
   nobody but the owner has used it.

## What is not built

Named here so it is not discovered later.

- **Phones do not sync.** `RemoteFamilySource` has no implementation. The
  merge is built, tested and specified (ADR-008, ADR-012) — nothing calls it.
  This is the largest gap between what the app looks like it does and what it
  does.
- **No collective reminder.** ADR-010; needs a paid plan or a nominated
  sender device.
- **No way to change the family after setup.** `FamilyEditor.addMember` and
  `removeMember` are built and tested; the setup screen is unreachable once a
  rota exists. R2.3 is delivered in the domain and absent from the app — the
  same shape of gap R1.4 had for ten days.
- **No sign-in.** Q3 was answered ("each of us signs in as ourselves") and
  never implemented. The journal's privacy copy is scoped to what is true
  today because of it.
- **iOS builds expire after seven days** on free provisioning (ADR-013).

## v1.1

Ordered by what the family would notice.

| Priority | Item | Why |
|:--:|:--|:--|
| 1 | [#74](../../issues/74) Change the family from inside the app | Built and unreachable. Somebody joins or leaves and the app cannot say so |
| 2 | [#75](../../issues/75) Wire Firestore sync | Four phones hold four separate rotas that can silently disagree |
| 3 | [#72](../../issues/72) Fix the release workflow | The next release is blocked until this is decided |
| 4 | [#76](../../issues/76) Sign in | Blocks #75, and the journal cannot honestly promise privacy without it |
| 5 | [#77](../../issues/77) A nominated reminder device | The closest thing to charter criterion S2 the free tier allows |

#77 is listed last and should be questioned before it is built: a sender that
only works when one particular phone happens to be on may be more confusing
than no sender at all. Worth asking the family rather than deciding for them
— which is the point the Product Owner persona has been standing in for all
fortnight.
