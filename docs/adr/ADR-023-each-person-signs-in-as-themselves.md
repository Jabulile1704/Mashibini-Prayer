# ADR-023 — Each person signs in as themselves

**Status:** Accepted · **Date:** 2026-11-09 · **Deciders:** Owner
· **Closes:** Q3

## Context

`DATA-MODEL.md` has carried an open question since Day 2:

> **Q3: does each member sign in as themselves, or does the family share one
> install?**
>
> … the decision is genuinely needed by Day 7.

It is Day 26. Nothing forced it until now, because Q3 changes exactly one
feature — journal privacy — and everything else works identically either
way. Day 25 is what forced it: every path in `firestore.rules` requires
`request.auth != null`, so **#75 cannot be built before #76**, and #76
cannot be built without answering Q3.

## Decision

**Each person signs in as themselves, with Google.**

**And the journal syncs**, privately, enforced by the rules rather than by
the UI.

Both answers are the owner's. The first closes Q3; the second settles what
Q3 said would follow from it.

### What the alternative would have cost

A shared account was the simpler answer and it was on the table. Its
consequence, written in `DATA-MODEL.md` since Day 2:

> R4.2 becomes unenforceable in the database — anyone holding the phone is
> every member at once … the honest fallback is journals stored **only on
> the device**, never synced, with the privacy claim in the UI reduced to
> match

That is the part that decided it. The app currently tells people their
journal is private. Under a shared account that sentence would have had to
be rewritten downwards, and an app that walks back a promise about somebody's
private writing is worse than one that asks them to sign in once.

### Google, and not the alternatives

ADR-010 already ruled on this from the free tier's constraints:

- **Never email link.** Five sends a day across the whole project is one
  person retrying on a bad-signal evening and then nobody being able to
  sign in at all.
- **Phone/SMS is not available on Spark.**

That leaves Google or email-and-password. Google, because the family's
phones already have Google accounts on them and a password is a thing to
forget.

## A uid belongs to exactly one person

`FamilyEditor.linkUid` refuses an account already on another member, rather
than moving it.

Moving it silently would be the dangerous choice: two members sharing one
uid makes R4.2 unenforceable for the same reason the shared account did,
and the overwhelmingly likely cause of the collision is that somebody
picked the wrong name on a phone. Reassigning would quietly hand one person
another's journal.

Linking is **idempotent** — signing in twice on the same phone must not be
an error, and on a free iOS provisioning profile that happens about weekly.

## Signing out does not unlink

Two different things that look alike:

| | What it means | What it does |
|:--|:--|:--|
| **Sign out** | this phone is no longer holding your account | nothing to the family |
| **Unlink** | the wrong name was picked and must be undone | removes the uid |

Signing out must not unlink, because it would drop that person out of
`memberUids` and stop **every other phone** from syncing changes they
make. One person signing out on a borrowed phone would silently degrade
the family's sync.

## Consequences

**`Family.memberUids` is empty until somebody signs in**, which correctly
means a family that has not signed in cannot sync. That is the honest
consequence, not a loophole to route around.

**The journal's promise becomes enforceable** rather than aspirational. It
is also now a thing that can be got wrong in a way that matters, which is
why journal sync is its own piece of work rather than part of this one.

**The About screen's "what it cannot do yet" shrinks**, and must be edited
as each line stops being true. It currently says the phones do not see each
other. That stays true until #75.

**Members who have not signed in still take their weeks.** They appear in
the family, they lead when it is their turn, and they simply cannot sync
from their own phone. The rota has never needed an account and still does
not.
