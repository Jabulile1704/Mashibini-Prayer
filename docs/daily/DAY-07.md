# Day 7 — Changing the family, and converging

**Date:** 2026-10-25 · **Phase:** 4, implementation · **Roles on point:** DBA, Developer

## Planned

Firebase: the project, the auth decision, and the Firestore wiring (R2.3,
R6.2). Issues #8 and #9.

## Delivered

| # | What | Where |
|:--|:--|:--|
| #44 | `FamilyEditor`, `FamilyMerge`, `IdGenerator`, the remote seam, ADR-008, the Firebase handover | merged to `develop` |

220 tests, 99.4% line coverage. Six commits, each landing on `develop`
individually for the first time since the rebase change (ADR-007).

## What was not delivered, and why

**There is still no Firebase project.** Creating one requires the owner's
Google account, and a stub — a placeholder project id, a committed
`google-services.json` — would have produced a repository that looks finished
and fails on the first real device.

So the work went to the seam instead. `RemoteFamilySource` is an interface
with no implementation; everything above it is written and tested.
`docs/FIREBASE-SETUP.md` is the handover: roughly twenty minutes of console
work, with the one irreversible step (the Firestore location) called out.

**Q3 is still open and now genuinely blocking.** Day 8 is security rules, and
"only the author may read a journal entry" is a rule or a fiction depending on
whether the family shares one install. The setup document lays out both
branches rather than guessing.

## The defect the requirement found

The merge tests failed on their first run, and the failure was not in the
merge.

**Ids were counted from local state.** The fifth member was `m5`, the second
cycle `c2`. That is correct on one phone and silently wrong on two: both
devices mint `m5` for different people, a union keyed by id collapses them, and
somebody disappears from the rota.

Written on Day 6. Invisible to every test that existed, because every test
modelled one device. Found only because R6.2's test modelled two.

The fix: ids are generated, not counted. `IdGenerator` is an interface in the
domain so randomness is injected rather than reached for; `RandomIdGenerator`
draws eleven characters from an alphabet with no vowels and no look-alikes, so
an id read down a phone line cannot turn `0` into `O` and cannot spell a word.

The lesson is the one worth keeping: **the test that finds this kind of bug is
the one written from the requirement, not from the implementation.** A test
written from the code would have modelled one device, because that is what the
code did.

## Decisions

1. **ADR-008 — merging is a union of append-only logs.** A union has no loser
   to discard, which is the half of R6.2 that last-write-wins cannot satisfy.
   Commutative, idempotent and canonically ordered, each tested as a property.
2. **Canonical ordering is required, not cosmetic.** Without it two phones
   produce equivalent lists in different sequences, write them back, and each
   see the other's as a change — syncing at each other indefinitely over a
   difference that means nothing.
3. **Changes take effect at the next turnover.** Somebody's week must not
   change under them because a name was added on a Wednesday, and the week
   after a change keeps the leader it was already going to have.
4. **A removed member stays on the family.** Past epochs reference them, and a
   turn they led in March must keep their name.
5. **`Member.leftAt` is not implemented**, diverging from `DATA-MODEL.md`.
   Membership of the current cycle already answers who is in the rota, and two
   sources for one fact will eventually disagree. Flagged for the owner rather
   than settled quietly.

## Verified on hardware

The simulator still held the family created on Day 6, with the old counted
ids. Today's build opened it correctly — so the id change needs no migration,
which was theory in the morning and is a checked fact now.

It also showed something better. On Day 6 the screen read *"This week: Sisi,
until Saturday 24 October"*. Today, with the app closed for two days and
nothing having advanced anything, it reads *"Jabulile, until Saturday 31
October"*.

The handover happened by itself across a real week boundary. That is ADR-002's
entire argument — a derived leader cannot go stale — observed rather than
asserted.

## Open questions

**Q3** — individual sign-in or one shared install. Blocks Day 8's rules. It is
the only open question, and the only one that cannot be dissolved by design the
way Q1 was: it is a fact about how the family will use the app.

## Blocked

**Day 8 is blocked on Q3**, and on the Firebase project existing. Neither can
be worked around honestly: rules cannot be tested without an emulator
configured against a project, and a rule enforcing journal privacy cannot be
written before it is known whether privacy is enforceable at all.

If no answer arrives, Day 8's honest shape is: write the rules for the
individual-sign-in case that ADR-004 already assumes, mark them provisional,
and leave them undeployed. That is worth saying in advance so it does not look
like a decision made quietly on the day.

## Tomorrow — Day 8, security rules

Firestore rules and their tests (#10, R4.2, N3). See the blockers above.
