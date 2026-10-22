# Day 4 — Persistence

**Date:** 2026-10-22 · **Phase:** 4, implementation · **Roles on point:** DBA, Developer

## Planned

Persistence and the repository abstraction, with fakes for tests (R6.1).
Issue #5.

## Delivered

| # | What | Where |
|:--|:--|:--|
| #34 | `Family` aggregate, JSON serialisation, `KeyValueStore`, `LocalFamilyRepository`, 121 tests, ADR-006 | merged to `develop` |

`lib/src/domain` remains at 100% line coverage; `lib/src/data` is at 100% of
its executable lines, with one stated exception.

## Decisions

1. **ADR-006 — a key-value store, not a database.** The deciding argument was
   not size. Firestore's offline cache was the tempting option, since ADR-001
   already brings Firestore — but that cache exists only *after* a first
   successful sync and a sign-in. A new phone, offline, would have nothing,
   and whose week it is must never need a network. So the local store is
   independent of Firestore entirely.
2. **Serialisation lives in the data layer, not on the entities.** `toJson` on
   `Family` would give the domain two reasons to change: the rota's rules, and
   whatever the database wants this month.
3. **Two asymmetries in handling bad data, both deliberate.** A family written
   by a *newer* schema is refused outright — silently dropping a field you do
   not understand is how a migration corrupts data quietly. An unknown *cycle
   reason* degrades instead, because it is a label on a past decision and
   nothing computes with it.
4. **Corruption and failure are different things.** Unparseable storage is
   reported outward and treated as "nothing stored"; a store that throws
   propagates. Conflating them would turn a disk error into an invitation to
   set up a rota the family already has.

## A bug the analyser found before a user could

`watch()` originally seeded each listener with the current value via
`asBroadcastStream(onListen:)`. That callback is **silently ignored when the
source is already a broadcast stream** — so the seed would never have fired,
and every screen would have sat empty until the next change happened to come
along. On Day 5 that would have looked like "the app opens blank", and the
cause would have been three layers from the symptom.

Rewritten as `async*`. There are now tests asserting a listener receives the
current value first, on a populated device and on an empty one.

Related: before using a private named initialising formal, the question of
whether Dart permits one was settled by trying it rather than assumed — it
does, and maps `this._onCorruptData` to the public call-site name
`onCorruptData`. The alternative was suppressing a lint, which is worse.

## Known gap

`PreferencesKeyValueStore` has no unit test. It is three one-line delegations
with no logic, and `TEST-STRATEGY.md` puts thin vendor wrappers into
integration rather than mocking a vendor SDK into a shape we invented.

The honest consequence, recorded rather than buried: **nothing yet proves
persistence survives a real restart on real hardware.** The tests prove
everything above the `KeyValueStore` seam and nothing below it. It runs for
real for the first time on Day 5, and it is on the Day 13 release checklist.
The user has been asked whether that is late enough to be worth closing with a
`shared_preferences_platform_interface` dev dependency.

## Open questions

No new ones. **Q1** (turnover weekday) blocks Day 6; the stored family holds it
as a field, so nothing in today's work depends on the answer. **Q3**
(individual sign-in vs shared install) blocks Day 7.

## Blocked

Nothing.

## Tomorrow — Day 5, the first screen

This week, who is next, and the date it changes hands (R1.1, R1.2). Issues #3
and #4. The first time any of this is visible, and the first time the real
`shared_preferences` store runs.
