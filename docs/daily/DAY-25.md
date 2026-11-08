# Day 25 — The rules and the app had never met

**Date:** 2026-11-08 · **Phase:** 9, the v1.1 backlog · **Roles on point:** Developer, DBA

## Planned

Start #75, Firestore sync — the first thing the About screen admits the app
cannot do, and the thing every feature built since Day 20 assumes will
eventually arrive.

## Delivered

Not #75. Two things found before writing a line of it.

- **#75 cannot be built before #76.** The backlog has had them in the wrong
  order since it was written.
- **The security rules and the app disagree**, and have since Day 9.
- `Member.uid`, `Family.memberUids`, and the document that carries it
- `tool/emit_rules_fixture.dart`, and rules tests that read it
- 688 tests

## The order was wrong, and the rules say so

Before adding `cloud_firestore`, the rules were worth re-reading:

```
allow update: if isMemberOf(resource.data)
              && request.auth.uid in request.resource.data.memberUids;
```

Every path requires `request.auth != null`. **Sync cannot work before
sign-in.** #75 has been listed ahead of #76 in every plan this project has
written, and it is not buildable in that order.

Anonymous auth does not rescue it either: the `create` rule lets the first
person write a family containing their own uid, and `update` requires
already being a member — so a second device has to be *added* by the first,
which is an invite flow, which needs identity. The order is #76, then #75.

## The rules have been passing a test of nothing

`memberUids` appears in `firestore.rules` eleven times. Before today it
appeared **nowhere else in the repository**.

The rules tests build their own documents:

```js
const familyDoc = {
  name: 'Mashibini',
  turnoverWeekday: 7,
  schemaVersion: 1,
  memberUids: [JABU, SISI],
};
```

The app's serialiser produces `{id, name, turnoverWeekday, members, cycles,
skips, songs, schemaVersion: 4}` — and no `memberUids` at all. A rule asking
`uid in resource.data.memberUids` against a document without that field does
not evaluate false; it **errors**. Every sync write would have been refused,
on the first day anybody wired sync up, and the rules tests would have gone
on passing throughout.

### Why this one is different from the others

This project has collected several checks that could not fail. #103 was a
broken instrument. Day 20's was a tautology. #111 measured the wrong thing.

This is none of those. **The rules tests are correct and the serialiser is
correct, and they had never been introduced.** Each was verified against its
own idea of the document. Nothing in the repository held both at once, so
nothing could notice they described different shapes.

That is a gap between two components rather than a fault in either, and it
is invisible to any test that stays inside one of them.

## The fix is a fixture, not an assertion

`tool/emit_rules_fixture.dart` writes the document the app's own serialiser
produces. CI runs it before the rules suite, which now asserts the rules
**accept what this app writes** — not that the rules work, which was never
in doubt.

A Dart test cannot reach the Firestore emulator and a JavaScript test cannot
reach `FamilyJson`. A file on disk is the only honest seam between them.

It is **not committed**. A checked-in copy of a generated document goes
stale silently, which is precisely the failure being fixed — the rules and
the app agreeing on paper and not in fact. The suite fails with the command
to run if the fixture is missing.

## What `memberUids` costs

It is denormalised, and that is not a shortcut. Firestore rules cannot walk
a subcollection or iterate an array of objects, so "is the caller in this
family" has to be answerable from one flat field on the document.

It is empty until somebody signs in, which means **a family that has not
signed in cannot sync**. That is the honest consequence and not a loophole
to be worked around.

## Tomorrow

#76, now that it is established as the thing that comes first. Google
sign-in is already enabled in the Firebase console (`FIREBASE-SETUP.md`),
and ADR-010 rules out email-link on the free tier — five sends a day shared
across the project is one person retrying on a bad evening.
