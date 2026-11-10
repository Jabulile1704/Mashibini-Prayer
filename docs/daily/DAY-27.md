# Day 27 — A library the family can play, and a cloud on a 30-day fuse

**Date:** 2026-11-09 · **Phase:** 9, the v1.1 backlog · **Roles on point:** Developer, DevOps, PO

> Written on Day 29. The log was owed on the day and is late, which is its own
> small finding: two PRs went up, a release was cut, a bug reached a phone and
> was fixed, and none of it was written down until the day after next. The
> entry below is reconstructed from the commits, which is exactly the thing
> daily logs exist to avoid.

## Planned

#124, the music library — the owner's upgrade of the songbook from titles to
actual recordings. Azure was not planned; it arrived as a question.

## Delivered

- **A music library** (#125): each phone keeps its own audio, the songbook
  keeps the titles
- The tab renamed back to **Family**, keeping everything the songbook put in it
- **A startup bug found on a phone and fixed**, with the test that should have
  caught it
- **Azure behind a seam** (#127, ADR-024), on terms that let it be deleted
- Swift package lockfiles committed, which sign-in had left on a laptop

## The path does not go in the shared document

This is the whole design of the library, and it is the opposite of the
decision taken four days earlier.

A song **title** merges across phones — it is append-only family data and
ADR-008 already handles it. A **path** like `/var/mobile/.../a-song.mp3`
means nothing on anybody else's device. Sync it and the family sees a play
button that does nothing, which is worse than seeing no button at all.

So `AudioLibraryRepository` keeps the id-to-path mapping on the device, under
its own key, and the screen joins the two at render time. The leading control
differs per phone by design: a play button where the file is, an invitation to
add one where it is not. Both are honest.

**`Member.photoPath` made the opposite choice on Day 23** and put the path in
the family document. That was the same mistake, caught late; #75 will have to
strip those on the way in. The cost of getting it wrong there is the reason it
was kept out from the start here.

## The bug that reached a phone

The owner reported the app "taking a while to launch". It was not slow. It was
dead on the native splash screen, for ever, with no crash dialog — which from
outside is indistinguishable from slow.

`FirebaseIdentity`'s constructor read `FirebaseAuth.instance`, which throws
`[core/no-app]` until `Firebase.initializeApp()` has run. **That call existed
nowhere in the app.** `main()` died before `runApp`.

Three changes, and the middle one is the one that matters:

1. `FirebaseAuth` resolves on first use rather than in the constructor, so
   building the object can never kill startup again.
2. **Firebase failing is no longer fatal.** `main()` catches it and falls back
   to `NoIdentity`. Signing in is the only feature that needs a configured
   project — the rota, the journal, the tree and the songbook do not. A
   Firebase that will not start now costs one Settings row instead of the
   whole app.
3. A test that runs with Firebase deliberately uninitialised, which is the
   test binding's default — so the condition that broke the app is now the
   suite's normal case. The bug was reintroduced on purpose and watched to
   fail with the identical exception before the test was trusted.

### Why nothing caught it

Worth more than the fix. **Every test injects `FakeIdentity`**, so the only
code that ever constructs the real one is `main()` — the one file in this
project with no test at all.

The seam that makes the app testable is the same seam that hid the wiring. A
fake is a claim that the real thing behaves the same way, and nothing was
checking the claim at the only place it was made.

## Azure, and what checking changed

The owner has $200 of credit for 30 days and wanted Azure in the project.
Looking it up rather than remembering it changed what that should mean.

**Blob Storage was the entire case** — the thing ADR-010 blocks, and the
reason photographs and audio are stuck on one phone. No free Blob allowance
could be found, and the per-GB prices render as placeholders on Azure's own
pricing page. So Azure does not remove the cost of storing files; it moves the
bill. I had said otherwise an hour earlier, from memory. That is the Day 22
mistake again in a different costume, and the correction is in ADR-024 and in
the PR rather than quietly dropped.

What is free is Cosmos DB and Functions. Neither changes the answer: Firestore
already covers a four-person rota for nothing, and ADR-003 leans on its
offline persistence rather than on a write queue nobody has built.

And the sentence that set the terms, from Azure's own trial page: if you do
not move to pay-as-you-go within 30 days, the account and its services are
disabled — with nothing said about whether the data survives.

So Azure enters as **a spike behind `RemoteFiles`**, whose default
implementation is `FilesStayOnThisPhone`: a null object rather than a nullable
field, because `files?.upload(...)` at every call site is an invitation to
forget one, and "the file stays on this phone" is a real answer that deserves
a name rather than a silent no-op.

**Nothing throws.** An upload that did not happen is not an error — the file
is already on the phone before any of this runs, so the worst outcome of the
entire spike failing is the behaviour the app shipped with. That is ADR-024's
third term, and it is tested rather than hoped for: unreachable, 500, and a
server answering a sign-in page — which is what a lapsed subscription actually
returns — all pass quietly.

Removal is `az group delete` and dropping one `--dart-define`. If that ever
needs a Dart change, the term was broken and the bug is here.

## Also

The navigation bar was Family, then Songs, then Family again **inside one
day**, and already carries ADR-016, ADR-020 and ADR-022. Navigation is the
part of this app that has changed its mind most, which usually means five
destinations do not divide cleanly. Noticed rather than acted on.

## PR hygiene

Two catches, both repeats: a missing "How it was verified" heading, and a
branch name (`spike/`) that the allowed prefixes do not include. Days 16 and
19 had the first; Day 12 had the second. The Day 24 retrospective claimed no
repeats, which was wrong and has been corrected.
