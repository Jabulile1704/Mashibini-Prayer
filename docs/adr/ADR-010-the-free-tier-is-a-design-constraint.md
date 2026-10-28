# ADR-010 — The free tier is a design constraint, not a billing preference

**Status:** Accepted · **Date:** 2026-10-28 · **Deciders:** Owner, DevOps

## Context

The charter has said "Budget: free tiers only" since Day 1. On Day 11 the
owner confirmed it concretely: the Firebase project will stay on the **Spark**
plan.

That is not a budget note. Spark removes whole categories of solution, and
several of them are the obvious way to build parts of this app. The limits
were checked against Firebase's own pricing and documentation pages rather
than recalled.

## What Spark actually forbids

| | On Spark |
|:--|:--|
| **Cloud Functions** | **Not available at all.** Every Functions row reads "Not applicable"; deploying requires Blaze. |
| **Cloud Storage for Firebase** | **Not available at all** — every row, both bucket types. No file or image uploads. |
| **Phone / SMS sign-in** | Not available. Billed per SMS on Blaze. |
| **Email-link sign-in** | Allowed, but **5 emails per day, project-wide**. |
| Pub/Sub, Cloud Run, Cloud Tasks, Cloud Scheduler | Not available. No scheduled anything. |
| Sending push (FCM) | Receiving is free. **Sending needs a trusted environment** — a Function or a server — so no automated push. |

What it allows is generous: Firestore at 20,000 writes and 50,000 reads a day,
Google and email/password and anonymous sign-in, Hosting, Crashlytics,
Analytics, and security rules. For four people that is enormous headroom —
this family would need to open the app several thousand times a day to notice.

## Decision

**The app is built so that nothing it needs lives on the paid side of that
line.** Specifically, and permanently:

1. **No server-side logic, ever.** Rules do authorisation; the client does
   everything else.
2. **Reminders are local notifications**, scheduled on the device. Not FCM.
3. **No file or image uploads.** Nothing in v1 wants them, and v1.1 should
   know the door is shut.
4. **If individual sign-in is chosen (Q3), it is Google sign-in or
   email/password — never email link.** Five sends a day, shared across the
   whole project, is one person retrying on a bad-signal evening.

## The part worth noticing

**The architecture already satisfies this, and did so before anyone checked.**

- ADR-002 derives the leader by arithmetic rather than advancing a stored
  pointer — so nothing needs a scheduled job to turn the week over. A Cloud
  Function doing that weekly is the obvious design, and it would have been
  unbuildable.
- ADR-003 makes the local store the read path, so the app works offline and
  reads cost almost nothing.
- ADR-008 merges on the client, so convergence needs no server to arbitrate.
- Day 9's rules put authorisation in the database, which is the free
  substitute for backend logic.

Each of those was decided for its own reason — correctness, offline reading,
determinism. That they add up to an app that fits inside the free tier is a
pleasant accident of having made each decision on its merits.

It is worth recording precisely **because it was not planned**: the next
decision made for a good local reason may not be so lucky, and this ADR is
where to check.

## Consequences

**Good**

- The bill is structurally zero, not carefully managed. There is no payment
  method to surprise anybody.
- No server to run, secure, back up or pay for.

**Bad, and accepted**

- **"Tell everyone when the week turns over" cannot be built.** A notification
  that reaches the *other* phones needs a sender in a trusted environment.
  Each device can remind its own user — which is Day 12's design — but the app
  cannot nudge the family collectively. That is a real feature this app will
  not have, and it should be said plainly rather than discovered.
- Blowing a daily quota disables that product. The docs disagree about whether
  it returns the next day or the next month, and that ambiguity is itself a
  reason not to design close to the line.
- Quotas are per project, so a second app must not share this one.
- Linking any billing account — or accepting the $300 trial credit, or
  touching a paid Google Cloud API — **auto-upgrades the project to Blaze**.
  Worth knowing before clicking something in the console.
