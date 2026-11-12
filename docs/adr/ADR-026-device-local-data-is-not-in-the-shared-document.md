# ADR-026 — Device-local data does not live in the shared document

**Status:** Accepted · **Date:** 2026-11-12 · **Deciders:** Developer
· **Amends:** [ADR-021](ADR-021-the-tree-is-not-the-rota.md) Decision 3
· **Blocks:** #75

## Context

ADR-021 settled where a family photograph lives: the picker returns a file,
the file is copied into the app's own documents directory, and the path is
stored. No bytes leave the phone, so ADR-010's "no file or image uploads"
stands untouched. All of that is still true.

Where the **path** was stored is the problem. It went on `Member`, and
`Member` is serialised into the family document — the document #75 is about
to publish to the family's other phones.

ADR-021 saw this coming and said so, in Decision 3:

> **A path, not bytes.** Putting image data in the family document would
> send it to Firestore the moment #75 lands — which is precisely the upload
> this avoids. The field is a string and **will have to be dropped on the
> way in when sync arrives**, because another phone's path means nothing
> here.

So the decision was right, the consequence was foreseen, and it was written
down in the one place nobody reads while implementing `FirestoreFamilySource`
— an accepted ADR about a different screen, six days earlier.

It was also the wrong shape. "Dropped on the way in" handles the receiving
phone and leaves the sending one publishing a path into its own application
directory to everybody else. `FamilyMerge` unions members by id, so that
path is then carried between all four phones indefinitely, and can be handed
back to the phone that owns the photograph after it has moved.

## Decision

**A field that means something on only one device does not go in the
document the family shares. It goes in a store keyed by this phone, beside
the other things that belong to this phone.**

This is not a new idea in the codebase. It is the one the songbook already
follows:

| | Shared document | This phone |
|:--|:--|:--|
| A song | `Song` — title, who added it, when | `device.audio.v1` — `songId -> path` |
| A person | `Member` — name, role, parents, uid | `device.photos.v1` — `memberId -> path` |
| This device | — | `device.youAre.v1`, `device.reminders.v1`, `device.appearance.v1` |

`AudioLibraryRepository` was written on 9 November — three days after
ADR-021 was accepted — and `pubspec.yaml` says out
loud that the recording's path "is kept out of the shared document".
`DeviceSettingsRepository` opens with "Settings that belong to *this phone*,
not to the family." The rule was already stated twice. It had never been
applied backwards to the photograph that predated it.

## Why a list and not a search

The guard is an allowlist of every key the shared document may carry, at
every level, in `test/data/family_json_test.dart`.

A test that asserts `photoPath` is absent protects against `photoPath`. The
next device-local field will not be called `photoPath` — it will be a cache
key, a file handle, a notification id, a download token — and it will be
added by somebody who is thinking about the feature rather than about sync.

An allowlist fails on any key that is not on it. Adding one is then a
deliberate act, and the person adding it has to answer the question this ADR
exists to ask: *should the rest of the family receive this?*

It is the same move the Firestore rules made on Day 9, for the same reason,
and the comment there says it better than this one can:

> Spelling the subcollections out also means a new one has to be added here
> deliberately rather than inheriting access by accident.

## Consequences

**The schema version does not change.** It stays at 4. The guard in
`FamilyJson.fromMap` exists so a document written by a newer build cannot
silently lose a field in an older one; removing a field cannot do that.
Bumping it would make every older install refuse to read the family
outright, which is far worse than an old build showing no photograph.

**A migration runs once.** `PhotoPathsOffTheFamily` lifts whatever an older
build recorded onto the member into this phone's store, then rewrites the
document without it. It is deletable: once no install predates #140, the
file does nothing and can go.

**What ADR-021 promised the user is unchanged, and is now true of the
document as well as the bytes.** The Family screen still says photographs
stay on this phone, are never uploaded, and are lost on reinstall. Before
this ADR the second clause was true of the image and false of its address.

**The open question this leaves.** A photograph for a member who is later
removed from the family stays in `device.photos.v1` for ever. Nothing reads
it and it costs a few dozen bytes, but nothing clears it either. Recorded in
#140 rather than fixed here.

## Alternatives considered

**Drop the field on the way in, as ADR-021 planned.** Rejected: it fixes
the receiving phone and leaves every sending phone broadcasting a path into
its own private storage. The honest reading is that a document is either
shareable or it is not, and filtering at one end makes it the reader's job
to know which fields were a lie.

**Two serialisers — one for the save file, one for the wire.** Rejected as
the worse version of the same idea. `FamilyJson` serving two purposes that
were never told apart is the root cause here; the answer is to make the two
purposes agree, not to formalise the divergence. It also doubles every
future field decision and the merge would still have to be told which shape
it is holding.

**Keep `photoPath` and let the merge discard mismatched paths.** Rejected:
the merge cannot tell a path belonging to this phone from one belonging to
another. They are both absolute paths into an application directory, and on
the same model of phone they can be identical strings pointing at different
files.
