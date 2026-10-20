# ADR-003 — The local store is the read path

**Status:** Accepted · **Date:** 2026-10-20 · **Deciders:** Developer, DBA

## Context

S3 says the current week must be readable in aeroplane mode. R6.1 says the
rota, the verse and your own journal must all read with no connection. N1 says
the answer is on screen within two seconds of a cold start on a mid-range
Android.

Reading straight from Firestore satisfies none of these reliably: the first
read of a session can wait on the network, and a spinner where a name should be
is the app failing at the only job it has.

## Decision

The local store is the read path, always. Firestore is a background writer into
it.

```
Firestore ──listener──► local store ──► repository ──► controller ──► widget
```

Widgets never see a Firestore type. Repositories expose domain entities from
local state, and the remote source's only job is to keep that state fresh and
to push local writes outward.

## Consequences

**Good**

- The app opens to an answer, not a spinner, regardless of signal.
- Firestore's own offline persistence handles the write queue; we do not build
  a second queue on top of it.
- The repository interface is the seam that makes the domain testable with
  fakes, and would be the seam if the backend were ever replaced (ADR-001).

**Bad, and accepted**

- Two sources of truth exist briefly, and a stale local read is possible right
  after a remote change. For a rota that changes a handful of times a year this
  is invisible; for a chat app it would be unacceptable.
- Conflict resolution becomes ours to define (R6.2). Last-write-wins per
  document is the Day 7 default, with the cycle's epoch structure meaning a
  genuine conflict writes a *new* epoch rather than overwriting one.
- First launch genuinely has nothing to show and must say so, rather than
  pretending to load.
