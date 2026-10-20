# ADR-001 — Flutter and Firebase

**Status:** Accepted · **Date:** 2026-10-20 · **Deciders:** Developer, DevOps

## Context

Four family members on a mix of Android and iPhone need the same app. The
budget is zero. The developer builds Flutter and Firebase daily and has
shipped both before. The app needs shared state across four devices, offline
reads, and push-style reminders.

## Decision

Flutter for the client, Firebase for the backend — Firestore for data,
Firebase Auth for identity, and local notifications for reminders. No server
of our own.

## Alternatives considered

| Option | Why not |
|:--|:--|
| **Native Swift + Kotlin** | Two codebases for four users, and the Swift work the author is doing elsewhere does not transfer to Android. The rota logic would be written twice, which doubles the surface of the one thing that must not be wrong. |
| **Flutter + a small API of our own** | A server to host, secure, back up and pay for. Everything it would do, Firestore does with rules. |
| **Entirely on-device, no sync** | Simplest by far, and genuinely tempting. Rejected because the cycle has to agree across four phones — a rota that disagrees with itself is worse than no app. |

## Consequences

**Good**

- One codebase, both platforms, from a toolchain already installed and pinned.
- Firestore's offline persistence does the sync queue, so we do not write one.
- Security rules are testable in CI against the emulator (Day 8).

**Bad, and accepted**

- Vendor lock-in. Moving off Firestore later means rewriting the data layer —
  bounded by the repository interfaces in ADR-003, but real.
- Firestore has no `africa-south1` region at the time of writing, so data sits
  further away than it ideally would. For four users' names and a weekly
  rota this is latency we will not notice, but it is a POPIA conversation if
  the app ever leaves the family.
- The free tier is generous but not infinite; an accidental listener loop
  could cost real money. Mitigated by reads being served locally (ADR-003).

**Needs a decision later**

- Whether reminders use local notifications only, or Cloud Messaging. Local is
  enough for a handover the device can compute by itself, and is the Day 11
  default unless something forces otherwise.
