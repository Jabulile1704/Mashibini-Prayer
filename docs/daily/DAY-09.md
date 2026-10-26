# Day 9 — Security rules

**Date:** 2026-10-26 · **Phase:** 5, testing · **Roles on point:** DBA, QA

## Planned

Firestore security rules and their tests (#10, R4.2, N3).

## Delivered

| # | What | Where |
|:--|:--|:--|
| #49 | `firestore.rules`, 24 rules tests against the emulator, a CI job to run them, and a security fix found by them | merged to `develop` |

The `Security rules` job is now a **required check** on both protected
branches, added after it had passed once — a required check that has never
run blocks every pull request.

## The hole the tests found

The first CI run failed on one test: *nobody can delete a family*. It expected
a refusal and got a success. **Any member could have deleted the family
document, rota and all.**

The cause, which is worth keeping because nothing about the file looked wrong:

```
match /families/{familyId} {
  allow delete: if false;        // this

  match /{document=**} {
    allow read, write: if …      // was quietly overridden by this
  }
}
```

A recursive `{document=**}` matches **zero** path segments as well as many, so
it also matched the family document itself. `write` includes `delete`, rules
are OR-ed, and the narrower rule lost. `allow delete: if false` sat four lines
above, doing nothing at all.

Fixed by naming `members`, `cycles` and `skips` one at a time. A wildcard that
silently widens access is worse than three lines of repetition, and the
explicit form also means a new subcollection has to be granted access on
purpose rather than inheriting it.

**The test that caught it asserts a denial, not a permission.** `nobody can
delete a family` is exactly the sort of test that feels too obvious to write.
Had this PR only tested what should be allowed, the hole would have shipped
and nobody would have found it until a family lost their rota.

## Decisions

1. **The rules are tested against the emulator with a `demo-` project id**,
   which keeps it entirely offline. That is what let the rules be proven
   before any Firebase project exists — and on the day they were written, none
   did.
2. **`family.memberUids` is denormalised for the rules, not for the app.** A
   rule must answer "may this person read this document?" from the document
   itself; the alternative is a `get()` into a subcollection on every read.
   It is the one field in the model that serves the database rather than the
   family, and `DATA-MODEL.md` says so.
3. **Everything not named is denied**, so a new collection has to be thought
   about before it can be written rather than discovered in a bill.
4. **A member can still lock the others out** by rewriting `memberUids`.
   Within a family that is a social problem rather than a security one, and
   guarding it properly needs a notion of ownership the app does not have.
   Recorded as a v1.1 item rather than half-done here.

## What could not be done, and why

**The rules tests do not run on this machine.** The Firestore emulator is a
Java program and there is no JDK installed; `flutter doctor` shows no Android
toolchain either, so this Mac cannot build Android locally at all.

They run in CI, where `setup-java` guarantees a JVM, and the workflow says so
next to the step. A JDK was **not** installed, because that is a change to the
owner's machine and their call to make.

**The rules are not deployed and cannot be.** There is no project to deploy
them to. They are correct, tested, and inert.

## Open questions

**Q3** is still open, and the rules are **provisional** on it. That is written
into the rules file itself rather than only the documentation, because whoever
opens the rules is exactly the person who needs to know that if the family
shares one install, `request.auth.uid` is the same for everybody and the
journal rule protects nothing.

This is the fallback stated in advance in the Day 7 log, so it is a position
rather than a decision that appears to have been made quietly on the day.

## Blocked

Nothing for Day 10. The daily verse needs no Firebase and no answer to Q3 —
though **Q2** (which translation may be bundled and redistributed) blocks it,
and has been open since Day 1.

## Tomorrow — Day 10, the daily verse

One verse per day, the same for every member, readable with no connection
(#11, #12, R3.1, R3.2). R3.2 — attribution and licensing — gates R3.1: an
unlicensed translation cannot ship, so the licence question comes first.
