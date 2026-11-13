# Day 32 — #75 was two features wearing one issue number

**Date:** 2026-11-13 · **Phase:** 9, the v1.1 backlog · **Roles on point:** Developer, Architect

## Planned

Wire Firestore sync. One issue, open since 1 November, described as "the
largest gap between what the app looks like it does and what it does".

## Delivered

- **#75, first half** — the family document publishes, merges and converges
- `memberships/{uid}` in the rules, **six new rules tests**, run against the
  emulator in CI
- **A reinstall now costs a sign-in instead of an evening**
- **ADR-027**, and **#143** for the half that is a decision rather than code
- Q3 closed; R6.2 marked half delivered
- 792 tests, up from 762

## What was sitting there already

| Built | When | Called by |
|:--|:--|:--|
| `RemoteFamilySource` — the seam | Day 7 | nothing |
| `FamilyMerge` — union of append-only logs, tested as properties | ADR-008 | nothing |
| `SkippedTurn.withdrawn` — one-way, so an undone skip survives a merge | ADR-012 | nothing |
| `firestore.rules` — 28 tests against the emulator | Day 9 | **a database the app had never connected to** |

Day 30 said that last row out loud when the owner asked whether the app was
secure: the one real security check in the project guarded something nothing
touched. Today it guards something.

The work to connect them was genuinely small. `FirestoreFamilySource` is
fifty lines — one document reference and three calls — and that is
deliberate. Everything deciding *what* a family document contains is in
`FamilyJson`, tested without a network. Everything deciding *who may read
it* is in `firestore.rules`, tested against the emulator. A class with its
own opinions in the middle would be the one place neither suite reaches,
which is precisely the shape of the Day 30 finding.

## The finding: it was never one feature

Publishing a family is small. Putting a **second person's** phone in front
of an existing family is a different question, and the rules are the shape
of it:

```
allow get, list: if isMemberOf(resource.data);   // uid must be in memberUids
```

A phone that is not yet in `memberUids` cannot read the family — so it
cannot add itself to `memberUids` either, because that is an update to a
document it may not even see.

**That is not a gap. It is the only reason a family id is worth nothing.**
Without it, the rota is private only as long as nobody forwards an eleven-
character string. With it, there is nothing to forward.

So the second half needs somebody already in the family to admit you, which
is two screens and the words on them, and a decision about what happens when
the joining phone already has a rota of its own that cannot be merged. That
is ADR-027 and #143, not an afternoon of plumbing.

The issue had said "wire Firestore sync" for a month and nobody — me
included — had noticed it contained a design decision. **An issue title is a
plan written before the work, and this one was wrong in a way that only
reading the rules could show.**

## Why the first half is worth shipping alone

A phone that was already in the family gets its rota back by signing in.

That is not a consolation prize. ADR-021 and the Family screen both warn
that a reinstall loses everything, and on a free iOS provisioning profile
that is roughly weekly (#104). `memberships/{uid}` is the one thing a wiped
phone can ask for by a name it already knows — its own uid — and the answer
is the family id it needs.

It is one line of rules, the same shape as the journal rule:

```
match /memberships/{uid} {
  allow read, write: if signedIn() && request.auth.uid == uid;
}
```

And it is **not** a way in, which is the point and also a test: a stranger
writes their own membership record naming `f1`, and then still cannot read
`f1`.

## Local first, without exception

Every read is answered from the phone. Every write lands on the phone before
anything is attempted over the network. A push that fails is reported and
swallowed — a phone with no signal is the normal case, not a failed save,
and S3 says the app works without one.

The test for that sets the remote to throw and asserts two things: the save
completes, *and* the family is on the phone afterwards. One without the other
would pass for the wrong reason.

Two refusals are deliberate:

- **A document whose family id is not this phone's** is reported and
  dropped. ADR-008 unions logs within one family and has nothing to say
  about two; guessing would silently rewrite a rota.
- **An empty document is not an instruction to forget.**

## The echo

Our own write comes straight back on the watch, because a Firestore snapshot
listener hears itself. The repository merges whatever arrives, so the echo is
harmless rather than something to filter — but it is only harmless if the
merge settles.

The test for that arrives three times and expects **exactly one
correction**. Removing the echo suppression on purpose turned it red, along
with its neighbour, which is the only reason either is worth having.

## The one seam no test can reach

`FamilyJson.decode` has only ever been handed `jsonDecode`'s output.
Firestore builds its own `Map<String, dynamic>`, with `List<dynamic>` inside
it, and hands that to `fromMap`.

Same static types, different builder. The reads in `json_reads.dart` ask
`is Map<String, Object?>`, which is a different question to read than
`is Map<String, dynamic>` and the same one to answer — but "I reasoned about
it" is what Day 31 just finished criticising. There is now a test that
rebuilds the document the way Firestore would and round-trips it.

## Measured rather than assumed

`cloud_firestore` is not a small dependency, and the APK was already the
reason an install failed on the owner's father's phone.

| arm64-v8a, **debug** | |
|:--|--:|
| `develop`, before | 91 MB |
| with `cloud_firestore` | **95 MB** |

**+4 MB, and that is a debug figure**, which is inflated to the point of
being nearly meaningless — no minification, no tree-shaking, both
architectures' worth of unstripped symbols. The release number will be
different and is not yet known. It arrives with the next tag and belongs in
that release's notes rather than being discovered by somebody downloading
it.

Two smaller things pub settled rather than memory: `cloud_firestore ^6` does
not resolve against `firebase_core ^5` at all, and the constraint that does
is `^7.1.0`.

## Open

- **#143** — the second phone. A decision and two screens.
- **The release APK size.** Unknown, and now more interesting than it was.
- **Nothing has run against a real Firestore.** Every test here uses a fake
  remote or the rules emulator. The first genuine proof is two phones, one
  family, one of them offline — and that needs #143 to exist first.
- **Q5** — nobody fluent has checked the sayings' spelling. Unchanged.
- **The father's phone.** Still the Android version, still unanswered.
