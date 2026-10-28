# Day 11 — The prayer journal

**Date:** 2026-10-28 · **Phase:** 4, implementation · **Roles on point:** Developer, DBA

## Planned

Write an entry, look back through old ones (#13, #14, R4.1 and R4.3).

## Delivered

| # | What | Where |
|:--|:--|:--|
| #54 | `JournalEntry`, the journal repository, the journal and editor screens, ADR-010 | merged to `develop` |

292 tests, 99.6% line coverage.

## Built device-local, which is right under either answer to Q3

Q3 is still open. Rather than stall or guess, the journal is **device-local
only**, which is correct both ways:

- **Shared install** → device-local is the only honest answer; ADR-004 is
  superseded and this is already what it becomes.
- **Individual sign-in** → device-local is the local half of the local-first
  design, and syncing is added behind the repository seam.

So the wording on screen is scoped to what is true today: *"Stays on this
phone. Not sent anywhere."* rather than *"private to you"*, which this build
cannot promise because nothing signs in yet.

**The test asserts the stronger claim is absent**, not that the weaker one is
present. That way it fails if somebody later strengthens the wording without
adding the sign-in that would make it true.

## Storage, deliberately unlike the family

The family lives under one key (ADR-006). The journal does not — one key per
entry plus an index.

The family is a handful of records changing a few times a year. The journal is
**the first thing in this app that grows without limit**: writing daily for
ten years is thousands of entries, and one value would mean rewriting the
whole journal on every save and loading all of it to read one day.

ADR-006 predicted that `shared_preferences` would be outgrown by exactly this
case. The prediction was acted on rather than rediscovered.

## ADR-010 — the free tier is a constraint, not a preference

The owner confirmed the project stays on **Spark**. The limits were checked
against Firebase's own pages rather than recalled, because the design depends
on them: no Cloud Functions, no Cloud Storage, no scheduled jobs, no phone
sign-in, and **no way to send a push notification** without a trusted
environment. Email-link sign-in is allowed but capped at **five sends a day
across the whole project**.

**The architecture already fits, and did so before anybody checked.** ADR-002
derives the leader instead of advancing it, so no weekly scheduled job is
needed — the obvious design would have been unbuildable. ADR-003 reads
locally. ADR-008 merges on the client. Day 9 put authorisation in rules.

Each was decided on its own merits. That they add up to an app needing nothing
paid is luck, and ADR-010 says so, because the next locally sensible decision
may not be so lucky.

**One real cost, stated rather than discovered:** "tell everyone when the week
turns over" cannot be built. Reaching the *other* phones needs a sender in a
trusted environment. Each device can remind its own user — Day 12's design —
but the app cannot nudge the family collectively.

## The red build, and what it was about

CI failed on analysis and tests, in `lib/`, where everything passed locally.

The cause was **selective `git add` across three commits**: `app.dart`,
`main.dart` and `test/app_test.dart` were edited to pass the journal through
and never staged.

The working tree was correct, so every local check was correct — and
meaningless, because CI builds from what was *committed*. That is exactly what
a clean-checkout build is for, and it earned its place.

The habit to fix is not "stop staging selectively", which produces good
commits. It is `git status` **before** the push rather than after the failure.

## Decisions

1. **Device-local journal**, pending Q3 — correct under both answers, nothing
   wasted either way.
2. **One key per entry plus an index**, diverging from ADR-006 for the one
   collection that grows without limit.
3. **Clearing the box deletes the entry** rather than storing a blank:
   somebody emptying it wants it gone, not an empty day.
4. **`toString` omits the entry's text.** A journal's words are the one thing
   that should not surface in a log line or a test failure message.

## Open questions

**Q3** remains the only one. The owner has created the Firebase project and
asked what to do in the console; the answer given depends on Q3 for exactly
one step — which sign-in provider to enable, or whether to enable any.

## Blocked

Nothing for Day 12. Reminders are local notifications, which need neither
Firebase nor an answer to Q3 — and ADR-010 now makes local the only option
rather than merely the preferred one.

## Tomorrow — Day 12, handover reminders

Opt-in reminders before a turnover (#15, R5.1). Local notifications only:
Spark cannot send push, and an app that starts notifying uninvited is not a
good houseguest.
