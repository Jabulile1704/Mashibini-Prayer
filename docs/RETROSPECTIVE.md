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

The PR hygiene check caught me **four** times, and never twice on the same
rule: a branch prefix it does not allow, a `type:defect` label with no
`Closes #n` (Day 14), the same again, and on Day 19 a PR body that dropped
the template's "How it was verified" section — written by somebody who had
just spent the day verifying things on a simulator and did not think to say
so in the one place a reviewer looks.

That last one is the most useful of the four. The check is not asking
whether the work was verified; it is asking whether the *next person* can
tell. A gate that only ever caught other people's mistakes would be worth
less than one that keeps catching its own author.

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

### A ninth, of a different kind: a check that could not fail

The fix for "every release was signed with a different key" was a stable key
**and a step in the release workflow that printed the certificate's
fingerprint**, so a change would be visible.

That step printed nothing, on every release, for four releases, and passed:

```yaml
keytool -printcert -jarfile app-release.apk | grep -E 'Owner:|SHA256:' || true
```

`-jarfile` reads the v1 JAR signature. Flutter's release APKs are signed
v2/v3 and carry no v1 block, so keytool found nothing, grep matched nothing,
and `|| true` turned the failure into a pass (#103).

This one is worse than the eight above, and it belongs in a different row of
the table. Those were bugs in the app, found by using it. This was a bug in
**the thing that was supposed to find bugs** — and it was found only because
somebody went looking for a fingerprint in a log, did not find one, and
refused to assume it was fine.

Two rules fall out of it, and both are now applied:

- **A step whose job is to prove something must fail when it proves
  nothing.** `|| true` on a verification step is a contradiction in terms.
- **A check should be runnable by a person, on the artefact, by hand.** The
  replacement is a Dart tool that reads the v2/v3 signing block and runs on
  a laptop with no Android SDK against a downloaded APK — which is precisely
  what had to be done to discover the problem. Nine tests cover it, five of
  them the refusal cases.

### A tenth, the inverse of the ninth: a check that should be deleted

#103 was a check that could not fail and had to be **repaired**. Day 20 found
a check that could not fail and had to be **deleted**.

`RotaEngine` had guarded, since Day 2, that every cycle began on the family's
turnover weekday:

```dart
if (cycle.effectiveFrom.weekday != turnoverWeekday) throw …
```

That guard did real work for eighteen days — it is what made ADR-019's probe
throw, and so what stopped a Settings row from bricking the home screen. Then
#100 moved the turnover day onto the cycle, where it is derived from the
cycle's own anchor, and the guard became a comparison between a value and
itself.

Repairing it was never the question; the question was noticing. A check whose
two sides have quietly become the same expression still reads like diligence,
still passes, and will still be there in a year being counted as coverage.
Two of them went this way on Day 20, along with the engine's "the turnover
weekday must be an ISO weekday", which had come to ask whether a
`DateTime.weekday` is between 1 and 7.

The rule: **when a field becomes derived, every check that compared it to its
source is now a tautology.** Find them in the same change. The tests that
asserted those throws were deleted too, with a comment in their place saying
what happened and where the replacement lives — a test file that quietly
shrinks by two is the other way this gets missed.

### An eleventh, and the only defence that has worked

Day 21 found a third check that could not fail, and the three are different
species — which is why "write the test" has stopped being an adequate answer:

| | What it was | How it failed |
|:--|:--|:--|
| #103 | A release step printing a signing fingerprint | Read the wrong signature block, found nothing, and `\|\| true` turned that into a pass |
| Day 20 | `cycle.effectiveFrom.weekday != turnoverWeekday` | Became a comparison between a value and itself when the field became derived |
| #111 | An assertion that tab labels are not cut off | **Nothing.** It could fail, and did. It was measuring the test font, and the defect it reported never existed |

The first was a broken instrument. The second was a question that had stopped
having two sides. The third is the worst, because the assertion *looks* like
it is about the right thing: `findsOneWidget` on a label is a reasonable line
of test code that passes on "Settin".

**Breaking it on purpose and watching it pass** disqualified two of the three
candidate assertions on Day 21, in one edit and thirty seconds. It is cheap
and it works, and it would have caught the first two rows above.

**It did not catch the third, and could not.** The surviving assertion failed
exactly as a working assertion should, and reported a defect that did not
exist, because it measured text in a font where every glyph is a 1em square.
A test that can fail is not the same as a test that measures the right thing,
and nothing in "break it and watch" asks whether the apparatus is sound.

What caught it was running the app and looking at the screen — which is the
eight-times-repeated lesson at the top of this section, arriving from the
opposite direction. Every previous entry is a bug the tests missed and a
person found. This one is a bug the tests **invented** and a person
disproved. The rule is the same either way: **the running app is the ground
truth, and a number is only as good as what produced it.**

So it is now the rule for any test written to catch a *specific* defect: make
the defect, confirm the test fails, then fix it. Not for every test — most
tests are written against behaviour that is obviously present or absent — but
for every test whose job is to prove a thing cannot happen.

The corollary, from #111: **ask what the suite has never built.** The
accessibility sweep pumped every screen and had never built the navigation
bar, so ADR-016's claim about tabs on a phone was unverifiable from the day it
was written. A sweep named "every screen" is a sweep nobody re-reads the
definition of.

### A fourth species, and the first that nothing in the app could have caught

Day 29 found one that none of the three rules above reach, in
`tool/release.sh`:

| | What it was | How it failed |
|:--|:--|:--|
| Day 29 | The check that a release branch holds everything new | Compared the replay against `develop` instead of against what was **released** |

The script found the previous release by looking for the newest
`chore(release):` commit on `develop`. That marker records where `develop`
was when somebody remembered to cherry-pick it back — the same thing as the
release only if the cherry-pick was immediate. v2.0.0's was missed and fixed
two days later in #126, by which time three commits had already landed. The
marker came to rest **above** work that had never shipped.

v2.1.0 would have gone out with 9 commits instead of 18: no songbook, no
sign-in, no Firestore rules fix.

**Nothing would have failed.** And this is the part worth keeping:

- the script's own safety check is `git diff develop` on the finished branch,
  which compares the replay against `develop` rather than against the last
  release — it passes whether the list was right or wrong;
- the changelog is drafted from the same list, so it agrees;
- every test passes on either set, because **both sets are internally
  coherent**. The smaller one is a perfectly good app. It is just not this
  one.

The three earlier species were all checks that could not fail. This one is a
check that *could* fail and was pointed at the wrong question — and unlike
#111, which invented a defect and was disproved by looking at the screen,
**looking at the screen would not have helped**. The release would have run
beautifully. The only symptom available was a family opening the app in a
fortnight and finding the songbook gone.

So it extends the rule rather than repeating it: the running app is the
ground truth **for what the app does**. For what was shipped, the ground
truth is what is on `main` — not a label, not a commit subject, not anyone's
memory of when they did the cherry-pick. The fix computes the boundary from
content, and refuses rather than guesses when it cannot find one.

The deeper pattern across all four: **every one of them was a check that
agreed with itself.** A tautology agrees with itself by construction, a
broken instrument agrees with its own silence, a test in a fixed-width font
agrees with its own apparatus, and a release script agrees with its own
changelog. None of them had a second, independent source to disagree with.
That is the thing to look for, and it is not the same question as "can this
fail?".

### And a fifth that was not a check at all

Day 30, in `azure/sas-function`. The owner asked a plain question — "is my
application secure?" — and reading the code to answer it found this:

> The Function verified the caller's Firebase ID token against Google, with
> the audience checked against this project, and then signed a SAS URL for
> whatever blob name the query string asked for. The uid was used for one
> thing: a log line.

Any holder of a valid token could read, or overwrite, every file in the
container. Google sign-in admits any Google account, so that is very nearly
anybody.

The four above are all *failures of a check that existed*. This is the
other kind, and it needs saying separately because the defences built for
the first kind do not point at it:

| | What existed | What was missing |
|:--|:--|:--|
| Days 20–29 | A check that could not do its job | — |
| Day 30 | **Nothing** | Any check at all |

`test/data/remote_files_test.dart` is a careful suite. It covers the server
being unreachable, returning 500, and answering with a sign-in page — which
is ADR-024's third term, that the app survives Azure vanishing. It asks what
happens when the server **fails**. Nothing anywhere asked what happens when
it **succeeds**.

And no requirement had been broken. N3 names journal entries, in Firestore,
enforced by rules — satisfied, 28 tests, since Day 9. This was files, in
Blob Storage, reached through a Function. The requirement named a mechanism,
so it covered that mechanism and stopped there.

So the lesson is not another way to interrogate a check. It is where to look
for the absence of one:

- **Authentication is not authorisation.** Every place that proves who
  somebody is must separately decide what they may reach, and the second
  decision is the one that gets left out, because the first one is harder
  and feels like the work.
- **Ask what a test asks.** A thorough suite about failure modes reads like
  coverage and says nothing about the success path, which is where the
  authorisation lives.
- **A requirement that names a mechanism covers that mechanism.** N8 was
  added to name the decision instead, so it reaches the next place one gets
  made rather than only the one that existed when it was written.

It also reinforces the oldest entry here, from the opposite direction
again: **a person reading the code found it.** Not CI, not the suite, and
not the running app — the Function was never deployed and nothing in the app
ever called it, so there was no behaviour to observe. Some defects have no
symptom until the day they do.

### And a sixth that was written down in advance

Day 31, found while reading the document #75 was about to publish.
`Member.photoPath` is an absolute path into one handset's application
directory, and the family document carried it.

That is ordinary enough. What makes it a species is where the analysis was
already sitting — ADR-021, Decision 3, accepted six days earlier:

> The field is a string and **will have to be dropped on the way in when
> sync arrives**, because another phone's path means nothing here.

Correct, specific, and addressed to nobody. An ADR records a decision; it is
not an instrument, so it cannot fail, and nothing reads it at the moment it
becomes relevant. The person who would need that paragraph is implementing a
different issue a week later, in a different file.

| | What existed | What was missing |
|:--|:--|:--|
| Days 20–29 | A check that could not do its job | — |
| Day 30 | Nothing | Any check at all |
| Day 31 | **Correct analysis, in prose** | Anything that could act on it |

Two further things it taught, both worth more than the bug:

**The written-down intention was also the wrong shape.** "Dropped on the way
in" fixes the receiving phone and leaves every sending phone broadcasting a
path into its own private storage. Being right about the problem is not the
same as being right about the fix, and prose carries no test to tell them
apart.

**A convention established after a mistake does not reach back.** The
songbook split device-local paths out correctly on 9 November, three days
after ADR-021 was accepted —
`AudioLibraryRepository`, and a comment in `pubspec.yaml` saying the path is
kept out of the shared document. `DeviceSettingsRepository` opens with the
same sentence. The rule was stated twice and applied forwards only. Nothing
re-examined the code that predated it, because nothing could tell the
difference until sync existed.

So the defence is the one that keeps recurring here in different clothes:
**turn the sentence into something that runs.** The guard for this is an
allowlist of every key the shared document may carry rather than a test that
`photoPath` is absent, because the next device-local field will have a
different name and will be added by somebody thinking about a feature. N10
is ADR-021's paragraph, rewritten as a thing that fails.

### PR hygiene has caught eight mistakes, and three are repeats

| Day | What it caught |
|:--|:--|
| 12 | A branch name that did not follow the model |
| 16 | A body missing the "How it was verified" heading |
| 18 | A PR opened against the wrong base branch |
| 19 | The heading dropped again, in a different section |
| 23 | A title typed `style`, which is not in the project's vocabulary |

| 27 | The "How it was verified" heading dropped a third time |
| 27 | A `spike/` branch prefix, which the model does not include |
| 29 | A `docs/` branch prefix — on the PR that corrects this table |

Eight catches, and the claim of "no repeats" above was true when written and
is not any more: the verification heading has gone missing three times, and
a branch prefix three times.

The last row is the useful one. That PR was opened to say the hygiene gate
had caught seven things — and the gate caught it, for the same class of
mistake, while it was being written. `docs/` is an obvious name for a branch
holding nothing but documentation; it simply is not one of the five the
project allows, exactly as `style` was a real Conventional Commits type that
is not one of this project's nine, and `spike/` was the natural word for a
spike.

All three repeats of this rule are the same shape: **a name that is correct
in general use and wrong in this repository.** That is not carelessness and
it will not be fixed by trying harder, which is the argument for the check
rather than against the convention. It remains the cheapest automation
here: four shell steps and a regex.

The one on Day 23 is the most interesting, because the type was not a
careless choice. `style` is a Conventional Commits type in general use; it
simply is not one of the nine this project allows. A convention that is
*nearly* the standard one is exactly the kind a person gets wrong from
memory, which is the argument for the check rather than against the
convention.

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
