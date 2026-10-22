# Architecture

> Phase 3 of the SDLC. Written before the code so that Day 3 has something to
> build against rather than a blank file and good intentions.

## The shape of it

Four layers, dependencies pointing one way only — inward, towards the domain.

```
┌─────────────────────────────────────────────────────────┐
│  presentation    Widgets. Knows how things look.        │
│                  Knows nothing about Firestore.         │
├─────────────────────────────────────────────────────────┤
│  application     Controllers. Turns a tap into a call,  │
│                  a stream into something paintable.     │
├─────────────────────────────────────────────────────────┤
│  domain          Entities and the rota engine.          │
│                  Pure Dart. No I/O. No Flutter.         │ ←── the part that
├─────────────────────────────────────────────────────────┤      must be correct
│  data            Repositories and their sources:        │
│                  local store, Firestore, bundled assets │
└─────────────────────────────────────────────────────────┘
```

The rule that matters: **`domain/` imports nothing but `dart:core`.** Not
Flutter, not Firebase, not `dart:io`. The moment it needs a clock it takes one
as an argument.

```dart
// Not this — untestable without waiting for next Tuesday.
Member currentLeader() => _leaderOn(DateTime.now());

// This — every week of the next decade is a test case.
Member leaderOn(DateTime date) => …
```

That single constraint is what makes N2 ("testable without a device")
achievable, and the rota is the one thing in this app that cannot be allowed to
be wrong.

## Directory layout

```
lib/
  main.dart                  entry point, wires the container
  src/
    app.dart                 MaterialApp shell and routing
    domain/
      entities/              Member, Cycle, Turn, Skip, JournalEntry, Verse
      rota/
        rota_engine.dart     leaderOn(date), turnsFrom(date, count)
        week.dart            week arithmetic against the turnover weekday
    data/
      repositories/          the interfaces the application layer talks to,
                             and their local implementation
      serialization/         JSON in and out — the storage format lives here,
                             not on the entities
      sources/
        local/               on-device store — the read path
        remote/              Firestore — the sync path (day 7)
        assets/              bundled verses (day 9)
    application/             controllers, one per screen
    presentation/
      screens/               ThisWeek, Setup, Journal, Verse
      widgets/               shared pieces
test/
  domain/                    the bulk of it — pure, fast, no Flutter binding
  data/                      repositories against fakes
  presentation/              widget tests
```

## How data flows

Reads never wait on the network:

```
Firestore ──(listener, when there is a connection)──► local store
                                                          │
                                                          ▼
                                            repository ──► controller ──► widget
```

The local store is the **read path**, always. Firestore writes into it in the
background. This is why the app opens correctly in aeroplane mode (R6.1, S3)
and why a cold start never shows a spinner where a name should be.

Writes go the other way — to the repository, which writes locally and queues
the remote write. Firestore's own offline persistence handles the queue; we do
not build a second one on top of it.

## Decisions that shaped this

Recorded properly in `docs/adr/`:

| ADR | Decision |
|:--|:--|
| [001](adr/ADR-001-flutter-and-firebase.md) | Flutter and Firebase, over native or a server of our own |
| [002](adr/ADR-002-derive-turns-from-an-anchor.md) | Turns are computed from an anchor date, never stored as a pointer |
| [003](adr/ADR-003-offline-first-read-path.md) | The local store is the read path; the network is a background writer |
| [004](adr/ADR-004-journals-outside-the-family-tree.md) | Journal entries live outside the family tree, keyed by author |
| [005](adr/ADR-005-a-calendar-date-type.md) | The domain has its own date type, not `DateTime` |
| [006](adr/ADR-006-a-key-value-store-not-a-database.md) | A key-value store holds the family, not a database |

## Why serialization is not on the entities

`toJson` on a `Family` would be convenient and would tie the domain to a
storage format. The entities would then have two reasons to change: the rota's
rules, and whatever the database wanted this month.

So the mapping lives in `data/serialization/`, as pure functions over
`Map<String, Object?>`. The domain does not know it is ever written down, and
the format can change — a Firestore document shape, a migration, a different
store entirely — without touching a single entity.

It also keeps the round-trip tests pure: no I/O, no device, no plugin.

## What is deliberately not here

- **No state-management package yet.** The app has four screens and one
  interesting computation. A package gets added when something hurts without
  it, and that will be its own ADR. Until then: `ValueListenable` and
  `StreamBuilder`, which are already in the box.
- **No dependency-injection framework.** The container is a constructor call in
  `main.dart` that takes repositories and passes them down. Tests build their
  own with fakes.
- **No `build_runner`, no code generation.** Nothing here is repetitive enough
  to earn a generator and the build-time cost that comes with it.

Each of these is a decision to revisit if the app outgrows it, not a permanent
position — and each would be an ADR when it changes.
