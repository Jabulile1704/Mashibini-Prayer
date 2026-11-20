# Day 36 — The test was holding the lie in place

**Date:** 2026-11-20 · **Phase:** 9, the v1.1 backlog · **Roles on point:** Developer, QA

## Planned

Push the v2.2.0 tag. The owner said the service account secret was in.

## Delivered

- **#157** — About says what this build can do, derived rather than written
- The sweeps' hand-kept screen list replaced by one that is checked
- **A real contrast defect** on the screen added yesterday, found by that
  check on its first run
- **N13**, and two more entries in the retrospective
- 868 tests, up from 847

**The tag was not pushed.** `gh secret list` returns three secrets and
`FIREBASE_SERVICE_ACCOUNT` is not among them — nor is it a Dependabot,
Codespaces or environment secret, and there are no environments. Said to the
owner rather than tagging into a failure they had explicitly chosen to
avoid.

## So the day went to reading the app instead

v2.2.0 is on `main` and on the owner's iPhone. The About screen, under
**WHAT IT CANNOT DO YET**, says:

> **The phones do not see each other**
> Each phone keeps its own copy of the rota. Skipping a week on one phone
> does not show up on another one yet.

True for thirty-four days. It is also the headline of the release cut two
days ago, inverted, shipped, and sitting in a family's hand.

## And there is a test

It passed on every one of the four sync pull requests:

```dart
expect(
  find.textContaining('do not see each other'),
  findsOneWidget,
  reason: 'the family should not have to read a repository to find out',
);
```

The reason is right. The assertion was **keeping the false sentence on the
screen** — delete the lie and the suite goes red.

Eight entries in the retrospective are checks that let a defect through.
This is a check that holds one in. And it is not badly written: pinning
user-facing copy is a reasonable thing to want, and the comment says why
somebody wanted it.

### The fix was already in the same file

`_SayingsSection`, from R3.3 on Day 28, reads `SayingSource.reviewed` out of
the data and surfaces the caveat only if nobody has checked the spelling.
R3.3 exists because *"unchecked isiXhosa shown without a word looks exactly
like checked isiXhosa"* — the failure is silent, so the copy must come from
the fact.

So About is handed `canSync` and derives both halves. The test asserts both
branches, including that a syncing build does **not** contain the old
sentence, which is the inverse of the assertion that caused this.

The general form is narrower than "keep documentation up to date": **a test
that asserts a sentence exists is a test that will defend it.** Worth
writing when the sentence is a fact the code cannot express. When the code
*can* express it, derive it.

## The asymmetry nobody had said out loud

While rewriting the reinstall section: as of v2.2.0 **the rota survives a
wipe and the journal does not.**

On iOS, free provisioning means that wipe happens about weekly (ADR-013,
#104). So the part anybody could retype in a minute is the part that
survives, and the part nobody can is the part that does not. About says that
now, in those terms.

`firestore.rules` has carried a tested `journals/{uid}` rule since Day 9 and
nothing writes to it. Changing that would change a promise the app makes —
*"Nobody else in the family can read it, and neither can we"* — so it is the
owner's decision, not a quiet improvement. About states the position
honestly in the meantime: the rota goes up, the journal never does.

## The more embarrassing half

Found while adding the About branches to the sweeps.

`everyScreen` was a hand-kept list of names sitting **beside** the map of
screens it indexed. It had drifted: `'Songs we love'` twice, and `'The
family's phones'` not at all.

**So the screen added yesterday was never swept at any text size** — in a
commit whose own comment quotes Day 31's lesson that *"a sweep named 'every
screen' is one nobody re-reads the definition of"*. The comment went into
the map. The sweep iterated the list. Yesterday's pull request claimed both
sweeps built the screen from the day it existed; that was true of one map and
false of every loop.

Day 31's corollary was **ask what the suite has never built**. I asked, and
answered with the wrong artefact.

The list cannot be derived — `screens()` needs repositories `setUp` has not
built when the test list is collected — so it stays, and a test asserts it
**is** the map and holds no duplicates. Both halves broken on purpose and
watched to fail.

### What it found immediately

```text
Expected contrast ratio of at least 4.5 but found 4.20 for a font size of 13.0
```

A heading on the unswept screen, tinted `colorScheme.secondary` — the honey.
Settings' own `_Heading` sets no colour and uppercases; this one did neither,
because I wrote it from memory instead of copying it.

The defect was a day old, the sweep that catches exactly this already
existed, and the only thing between them was a list.

## CI failed on something that was not mine

The Android build went red three times: once on a Gradle
`NullPointerException` and twice on

```text
Could not find grpc-stub-1.84.0.jar (io.grpc:grpc-stub:1.84.0)
```

a transitive Android dependency of `cloud_firestore`. Checked rather than
assumed: that jar answers **200** from Maven Central. Two different failures
in one run, one of them an environment NPE, so it was re-run rather than
diagnosed, and it passed.

Recorded because the job already carries a three-attempt retry loop whose
error message reads *"Android build failed three times. This is not a rate
limit."* Somebody met this before. The honest state is that the Android build
is occasionally flaky for reasons outside this repository, and nothing here
distinguishes that from a real break except a person looking.

## Open

- **The v2.2.0 tag**, and the secret it waits on.
- **The journal does not sync.** A decision about a promise, not an
  implementation.
- **Two real phones.** Still the only test of #75 that counts.
- **#77** — the collective reminder. The last open story.
- **Q5** — nobody fluent has checked the sayings' spelling.
