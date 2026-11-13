# ADR-027 — The invitation is a person, not a link

**Status:** Accepted · **Date:** 2026-11-13 · **Deciders:** Developer
· **Builds on:** [ADR-008](ADR-008-merging-is-a-union-of-append-only-logs.md),
[ADR-023](ADR-023-each-person-signs-in-as-themselves.md)
· **Implemented by:** #75 (first half), #143 (the screens)

## Context

#75 was described for a month as one thing: "wire Firestore sync so the
phones see each other". Writing it showed it is two, and the second one is
not an implementation at all.

Publishing and merging a family document is small, because the pieces were
all built already — the seam on Day 7, the merge in ADR-008, the rules on
Day 9. Putting a *second* person's phone in front of an existing family is a
different question, and the rules are the shape of it:

```
allow get, list: if isMemberOf(resource.data);   // uid must be in memberUids
```

A phone that is not yet in `memberUids` cannot read the family. So it cannot
add itself to `memberUids` either, because that is an update to a document
it may not even see.

That is not a gap. It is the single reason a family id is worth nothing on
its own, and therefore the reason the rota is private without anybody having
to invent a password.

## The decision

**Somebody already in the family admits you, by name. There is no code, link
or identifier that lets a phone in on its own.**

Two consequences follow immediately, and they are the point rather than the
cost:

- **A family id is not a secret and never has to be treated as one.** It is
  in every copy of the document, in log lines, in whatever the owner pastes
  into a chat. Nothing about the security of the rota depends on keeping it
  quiet.
- **There is nothing to leak.** No invite code with a lifetime, no
  revocation list, no "anybody with this link can join", no screen asking
  whether you meant to share it. The feature that would need those does not
  exist.

## What this rejects

**An invitation document with a code in it.** `invitations/{code}` holding a
family id, readable by any signed-in account, plus a rule letting a signed-in
account add *only its own uid* to `memberUids`. That last part is expressible
in rules — the difference of the two sets has to be exactly the caller's uid
— and it is the conventional answer.

Rejected for what it changes rather than for what it costs: it makes the
family id, or a code standing in for it, the thing that grants access. Every
such code then needs a lifetime, a revocation, and a decision about what
happens when it is forwarded. A four-person family rota does not need an
access-control subsystem, and the version with none is strictly easier to
reason about.

**A phone adding itself once it knows the id.** Same objection in a smaller
package, and it would require relaxing the one rule that currently makes the
whole model hold.

## `memberships/{uid}` is not that code

The first half of #75 added a collection, and it is worth being precise
about why it is not the thing just rejected:

```
match /memberships/{uid} {
  allow read, write: if signedIn() && request.auth.uid == uid;
}
```

One document per account, holding a family id and nothing else, readable and
writable only by that account. It answers exactly one question — *which
family did I say I was in* — for exactly one asker.

It hands out a family id, and a family id is worth nothing, which is the
whole argument above running in the other direction. There is a rules test
that says so outright: a stranger writes their own membership record naming
`f1`, and then still cannot read `f1`.

What it buys is the reinstall. A wiped phone has the account and nothing
else; this is the one thing it can ask for by a name it already knows.

## Consequences

**#75 ships in halves, and the first half is useful on its own.** A phone
that was already in a family gets its rota back by signing in. That is worth
having for its own sake — ADR-021 and the Family screen both warn that a
reinstall loses everything, and on a free iOS provisioning profile that is
roughly weekly (#104).

**The second half is two screens and the words on them** (#143). The
mechanics are done: `FamilyEditor.linkUid` puts a uid on a member and is
tested; `SyncingFamilyRepository` saves an arriving document whole when the
phone has nothing to merge it with. What is missing is how Sisi's phone
shows her account identifier, how it reaches Jabulile, and what the app says
when Sisi already has a rota of her own that cannot be merged with the one
she is joining.

**A Firebase uid is a bad thing to read aloud.** Twenty-eight characters,
mixed case, no error detection. `RandomIdGenerator` avoids vowels and
look-alikes precisely because its ids "end up read aloud down a phone
line"; a uid has none of that and cannot be given it. #143 therefore has to
move it as text — the `Sharing` port is already wired, so one tap into
WhatsApp — rather than ask anybody to dictate it.

**Two families still cannot become one.** `SyncingFamilyRepository` reports
and drops a document whose family id is not this phone's. ADR-008 unions
append-only logs *within* one family; it says nothing about two, and
guessing which one the person meant would silently rewrite a rota. Telling
somebody plainly that they have to choose is the honest behaviour, and it is
the one #143 has to put words to.
