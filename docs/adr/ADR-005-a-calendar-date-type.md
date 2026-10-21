# ADR-005 — A CalendarDate type, not DateTime

**Status:** Accepted · **Date:** 2026-10-21 · **Deciders:** Developer, QA

## Context

`DATA-MODEL.md` decided that dates are stored as `yyyy-mm-dd` rather than as
instants, because a turnover is a calendar event and an instant invites a
timezone to move it across a day boundary.

That settles the database. It does not settle what the code passes around.
Dart's `DateTime` always carries a time and an offset, so using it in the
domain would mean every function normalising its input, and every one of them
being a place to forget.

## Decision

The domain has its own `CalendarDate`: a year, a month and a day, with no time
and no timezone. It can be compared, added to in whole days, and printed as
`yyyy-mm-dd`. It cannot represent an hour.

Internally it holds a `DateTime` pinned to midnight **UTC**, because UTC has no
daylight saving, so adding a day is always exactly 24 hours and never 23 or 25.
That is an implementation detail and nothing outside the class sees it.

`CalendarDate.from(DateTime)` is the single, explicit bridge from a real clock,
and the engine never calls it — the caller decides what "today" means.

## Alternatives considered

| Option | Why not |
|:--|:--|
| **Plain `DateTime`, normalised at the boundaries** | Correct only while everyone remembers. The type still permits `DateTime.now()` deep inside the domain, which is exactly the untestability ADR-002 was written to avoid. |
| **A `package:` date library** | A dependency, its updates and its API, for a type whose whole surface is about eighty lines and fully tested. Reconsider if the app ever needs real timezone handling. |
| **Storing an epoch day number (int)** | Compact and fast, and unreadable in the database. The rota's data should be legible to a person looking at Firestore. |

## Consequences

**Good**

- A time of day cannot leak into the rota, because the type cannot hold one.
- `DateTime.now()` cannot appear in the domain: there is nowhere to put it.
- `parse` rejects both a full timestamp and an impossible date like
  `2026-02-31`, rather than quietly rolling the latter into March.

**Bad, and accepted**

- A conversion at every boundary — the UI and the data layer both translate.
  The conversions are one line each and explicit, which is the point.
- Reimplementing a little of what `DateTime` already does, including the tests
  that prove leap years and month ends behave.
