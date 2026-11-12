# Day 31 — The ADR that predicted the bug and could not prevent it

**Date:** 2026-11-12 · **Phase:** 9, the v1.1 backlog · **Roles on point:** Developer, Architect

## Planned

Start #75 — wire Firestore sync, the largest remaining gap between what the
app looks like it does and what it does.

## Delivered

- **#140**, found while reading the document #75 would publish
- `PhotoLibraryRepository` and a one-time migration, 13 tests
- An **allowlist** of every key the shared document may carry
- The rules fixture furnished rather than minimal: a skip, a song, a parent
- **ADR-026**, **N10**, and a sixth species in the retrospective
- 762 tests, up from 746

**#75 did not get started.** Reading what it was going to send was the first
step, and the first step was enough for one day.

## The first question #75 asks

Not "how do I write to Firestore". That part is small. The question is
*what exactly goes in the document*, because once it is published to four
phones, every field in it is a promise about what the other three will do
with it.

`FamilyJson.toMap` was the answer, and it has one field too many.

```dart
/// A photograph on **this phone**, as an absolute path.
final String? photoPath;
```

That string is `/data/user/0/com.mashibini.prayer/app_flutter/family-photos/
m1-1762…jpg`. Published to the family, it is a real file on one handset and
nothing at all on the other three. And `FamilyMerge` unions members by id,
so it would not have been dropped — it would have been carried between all
four phones indefinitely, and could be handed *back* to the phone that owns
the photograph after that phone had moved it.

The screen already made a promise about this. Under the family tree:

> Photographs stay on this phone. They are never uploaded — which also means
> the others cannot see them.

True of the image. False of its address, the moment #75 landed.

## The part worth keeping

**It was written down. Three weeks ago, correctly, in an accepted ADR.**

ADR-021, Decision 3, in the paragraph headed *A path, not bytes*:

> The field is a string and **will have to be dropped on the way in when
> sync arrives**, because another phone's path means nothing here.

So this is not a defect anybody missed. It is a defect somebody **saw,
understood, and recorded** — and then nothing happened, because an ADR is a
record of a decision, not an instrument that can fail. There is no CI job
that reads the consequences section of ADR-021 and checks whether sync has
arrived yet.

Four hundred words of correct analysis, addressed to a person who would be
implementing a different issue a week later, and who had no reason to open
that file.

And it was the **wrong shape** besides. "Dropped on the way in" fixes the
receiving phone and leaves the sending one broadcasting a path into its own
private storage to everybody else. A document is either shareable or it is
not; filtering at one end makes it the reader's job to know which fields
were a lie.

## The pattern the codebase already had

The songbook got this exactly right **three days later**:

| | Shared document | This phone |
|:--|:--|:--|
| A song | `Song` — title, who added it, when | `device.audio.v1` |
| A person | `Member` — name, role, parents, uid | **nothing** → now `device.photos.v1` |

`pubspec.yaml` says out loud that the recording's path "is kept out of the
shared document". `DeviceSettingsRepository` opens with "Settings that
belong to *this phone*, not to the family."

**The rule was written down twice and never applied backwards.** A
convention established after the mistake does not reach back and fix it, and
nothing was looking at the gap, because the only thing that could tell the
difference is a sync that does not exist yet.

## Why the guard is a list

The obvious test is `expect(encoded, isNot(contains('photoPath')))`. It would
pass for ever and protect against exactly one field.

The next device-local thing will not be called `photoPath`. It will be a
cache key, a download token, a notification id, and it will be added by
somebody thinking about that feature rather than about sync — which is
precisely how this one arrived.

So the guard is an **allowlist**: every key the document may carry, at every
level, walked recursively. Any key not on it fails the suite. Adding one is
then a deliberate act by somebody who has had to answer the question
out loud.

That is the same move `firestore.rules` made on Day 9, and its comment says
it better:

> Spelling the subcollections out also means a new one has to be added here
> deliberately rather than inheriting access by accident.

## What the fixture had never been asked

While widening the guard: the rules fixture was a family with two signed-in
members, one cycle, **no skips and no songs**.

`songs` arrived on 7 November. The rules were written on Day 9. Until today, no
test had ever offered the rules a document with a song in it — the fixture
proved the rules accept the document the app writes, for the one family
shape somebody happened to build in a tool script.

It is furnished now: a skip with a note, a song, a parent edge, a role. CI's
`Security rules` job accepted it against the emulator on the first run, so
there was no latent rejection waiting — but that is now a fact rather than
an assumption, and it is the kind of fact that only stays true if something
checks it.

## Breaking it on purpose

`FamilyJson.devicePhotosIn` was made to return nothing and the suite re-run.
Two tests went red, including *"keeps a photograph that was stored on the
member"*. Restored, green again.

One thing that probe said that I would not otherwise have known: *"and takes
it out of the document"* **still passed** with the harvester broken, because
re-encoding drops the field whether or not anything rescued it first. Two
tests that look like they cover the same migration cover different halves of
it, and only one of them notices when the photographs are silently lost.

## One correction

The commit message and the PR body for #140 both say the songbook made the
right call "three weeks later". It was **three days**: ADR-021 was accepted
on 6 November, `AudioLibraryRepository` landed on 9 November. Checking the
dates after writing the sentence rather than before is how that got in, and
the merged message cannot be changed now.

It makes the point sharper rather than softer. This was not a convention
drifting away from old code over a month. The same developer wrote the rule
down, correctly, three days after writing the ADR that said the old code
would need it — and did not go back the three days.

## Open

- **#75 itself.** Nothing is wired. The seam, the merge, the rules and the
  fixture are all ready; what is missing is `FirestoreFamilySource` and the
  answer to *how does a second phone find the family it belongs to*. That
  second question needs a decision, not an implementation.
- **An orphaned photograph.** A member removed from the family leaves their
  path in `device.photos.v1` for ever. Nothing reads it, nothing clears it.
  In #140, not fixed.
- **Q5** — nobody fluent has checked the sayings' spelling. Unchanged.
- **The father's phone.** Still the one unanswered question from Day 30: the
  Android version. No build installs below 7.0 and nothing else can be
  concluded until that number exists.
