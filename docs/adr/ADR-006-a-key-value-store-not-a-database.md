# ADR-006 — A key-value store for the family, not a database

**Status:** Accepted · **Date:** 2026-10-22 · **Deciders:** DBA, Developer

## Context

ADR-003 made the local store the read path: the app opens to an answer, not a
spinner, and the rota is readable with no connection (R6.1, S3). That decided
the *shape* of the data flow and said nothing about what the local store
actually is.

What has to be stored is small and changes rarely: one family, four members, a
handful of cycle epochs, and the occasional skip. A few hundred bytes, edited
perhaps a dozen times a year.

## Decision

`shared_preferences`, holding the whole family as a single JSON document under
one key.

Behind a `KeyValueStore` interface of three methods — `read`, `write`,
`delete` — so that the repository depends on the idea of storage rather than
on the package.

## Alternatives considered

| Option | Why not |
|:--|:--|
| **SQLite (`sqflite`, `drift`)** | A schema, migrations and a query language for data that is read whole, written whole, and never queried. The migration machinery alone is more code than the thing it would migrate. |
| **Hive / Isar** | Fast, and designed for far more than this. A binary store also loses the thing that makes a bug findable at 11pm: being able to read what is actually saved. |
| **A JSON file via `path_provider`** | Nearly the same thing, plus directory handling, partial-write and permission cases we would own. `shared_preferences` is that, already written. |
| **Firestore's offline cache alone** | Tempting, since ADR-001 already brings Firestore. Rejected because the cache is only populated *after* a first successful sync, and only after sign-in. The first run on a new phone, offline, would have nothing — and "whose week is it" is exactly the question that must not need a network to answer. |

That last row is the real decision. The others are about size; this one is
about whether R6.1 holds on day one of an install.

## Consequences

**Good**

- Three methods to implement, and the test double is a `Map`.
- What is stored is legible: `yyyy-mm-dd` dates and readable keys, so a
  support question can be answered by looking.
- The repository never imports the package, so replacing it later touches one
  file.

**Bad, and accepted**

- Whole-document writes. Two writers racing would clobber each other rather
  than merging — acceptable while the only writer is this device, and the
  reason R6.2's conflict handling is a Day 7 question about *Firestore*, not
  about this store.
- `shared_preferences` is not meant for large values. A family that grew to
  thousands of skips would outgrow it, which is several orders of magnitude
  past what four people generate in a lifetime. The `KeyValueStore` seam is
  where that would be fixed.
- No partial reads: the whole family is parsed on open. At this size that is
  below the threshold of measurement.

**On testing the wrapper**

`PreferencesKeyValueStore` is three one-line delegations with no logic, and on
Day 4 it was left untested on the grounds that thin vendor wrappers belong to
integration. That was half right, and the half that was wrong mattered: the
wrapper is exactly where a wiring mistake would hide while every other test
still passed.

It is now tested against `InMemorySharedPreferencesAsync` — the package's own
implementation of its own interface, which encodes no guess of ours about how
`shared_preferences` behaves. See `TEST-STRATEGY.md`, "Vendor code: a
distinction worth making".
