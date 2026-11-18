# Day 34 — The join code was the same eleven characters for everybody

**Date:** 2026-11-18 · **Phase:** 9, the v1.1 backlog · **Roles on point:** Developer

## Planned

#143 — let somebody already in the family admit a second phone. The decision
was taken yesterday in ADR-027; this was meant to be the screens.

## Delivered

- **#148**, found in the first five minutes of looking at #143
- `TheFamilyNeedsItsOwnId` — a migration, 9 tests
- The `familyId` parameter **removed**, so the literal cannot be passed again
- Two more stale claims corrected, in `FIREBASE-SETUP.md` and inside a test's
  own preamble
- 805 tests, up from 792

**#143 did not get started.** What a joining phone has to be given is the
family's id, so the first step was to look at what one is.

## What one is

```dart
final Family family = RotaSetup.build(
  familyId: 'f1',
```

**Every family this app has ever created is called `f1`.**

## Harmless for twenty-five days

Nothing read it. The id distinguished one family from the others inside a
single phone's storage, where there are none — so a constant worked
perfectly, and no test had reason to object, because nothing was wrong.

Day 32 made it the Firestore document path.

## What it does now, precisely

The rules stop it being a leak, and reading how is worth the two minutes:

- The first family to sign in creates `families/f1` with their own uids.
  `allow create` requires the creator to be in `memberUids` — succeeds.
- Every other family's push is an **update** to a document that now exists,
  so `allow update: if isMemberOf(resource.data)` asks whether they are in
  the *first* family's `memberUids`. They are not. Refused, and so are reads.

So nobody sees anybody else's rota. The rules held, for the fourth time this
fortnight. What happens instead is that **the first family to sign in owns
`families/f1`, and every other family's sync fails silently for ever** —
`SyncingFamilyRepository` swallows a failed push by design, because a phone
with no signal is the normal case, so the only symptom is a `debugPrint`.

One family uses this app today. Nothing is broken in practice. That is luck.

## The shape of it

Nothing here was wrong when it was written. The constant was correct under
the only meaning the field had. Then Day 32 gave the field a second job —
local identifier *and* globally unique document path — and **nothing went
back to look at the values that were fine under the first one.**

That is Day 31's lesson arriving from the other side. On Day 31 a *rule* was
established after the mistake and never applied backwards. Here a *meaning*
was established after the value, and the value was never re-examined.

So the generalisation worth keeping: **when a field acquires a second job,
every existing value is a new input.** Not "re-read the code", for which
there is no budget — specifically: a field whose meaning has widened has a
finite, findable set of places that set it, and all of them are now
unchecked.

## The project had written it down. Twice.

| Where | What it says |
|:--|:--|
| `lib/src/domain/ids.dart` | "A new id beginning with `prefix`, **unique without coordination**" |
| `RandomIdGenerator` | eleven characters, no vowels, no look-alikes, because an id "ends up read aloud down a phone line" |
| `docs/FIREBASE-SETUP.md` | "Collision-safe ids \| Done (ADR-008)" |

Members, cycles, skips and songs all use the generator. The one id that has
to be unique between phones that have never met was a string literal.

And `test/domain/id_scheme_change_test.dart` opens by saying families created
after ADR-008 "have random ones" — true of everything *inside* a family, and
never true of the family. Both say so now.

That is the fourth day running on which a document flattered the project.
Day 31 found two in `REQUIREMENTS.md`, Day 33 found three in
`FIREBASE-SETUP.md`, and this is a fourth in the same file plus one living
inside a test.

## The migration renames `f1` and nothing else

Deliberately narrow, and the narrowness is the part worth stating:

- a family whose id came from the generator is already right;
- a family this phone **joined** carries the id of the phone it joined, and
  renaming that would quietly detach it from the family it belongs to —
  worse than the bug being fixed.

It runs before the family is read and before `FindMyFamily` writes down which
family the account is in, so no membership record is ever written against an
id that is about to change.

## Then the parameter went away

The first fix was a value, and a test asserting that a value is right has to
be remembered.

`RotaSetup.build` no longer takes a `familyId`. The generator was already an
argument — the cycle needs an id — so there was never anything for the caller
to supply. **A caller who cannot name it cannot name it wrongly.**

Same move as `blobNameFor` on Day 30, and the same sentence applies: a
blocklist has to anticipate the input; making the bad input inexpressible
does not.

The new tests assert the property rather than the mechanism — two phones
setting up separately produce different families. "It is random" is a weaker
and less relevant claim than the one that broke.

## Why this was a pull request and not a hotfix

Nothing is live. The released app (v2.1.0) has no Firestore in it at all, and
the rules were only deployed on 18 November, so **no phone has ever written
to `families/f1`.**

Had v2.2.0 gone out first — which it nearly did, twice, when the owner asked
for an APK link — this would have been the other kind of morning: a live
document owned by whichever phone signed in first, and a migration obliged to
rename an id somebody was already syncing against.

## Open

- **#143**, still. Unblocked now, and with a join code worth pasting.
- **The service account.** The next release still fails without it, on
  purpose (ADR-028).
- **Nothing has yet run against the real Firestore.** Unchanged, and now
  slightly more pointed: the first sign-in is also the first test of the id.
- **v2.2.0 uncut.** Nineteen commits unreleased, including the APK split the
  owner's father needs.
- **Q5** — nobody fluent has checked the sayings' spelling.
