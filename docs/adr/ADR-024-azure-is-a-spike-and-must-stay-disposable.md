# ADR-024 — Azure is a spike, and must stay disposable

**Status:** Accepted · **Date:** 2026-11-09 · **Deciders:** Owner
· **Does not supersede:** [ADR-010](ADR-010-the-free-tier-is-a-design-constraint.md)

## Context

The owner has **$200 of Azure credit, valid for 30 days**, and wants Azure
in the project.

Two things the app has wanted since ADR-010 are blocked on file storage:
photographs on the family tree (#109) and now audio in the songbook (#124).
Both are "on this phone only, lost on reinstall" because Firebase Storage
needs the paid plan.

Azure looked like the answer. Checking rather than remembering changed that.

## What the checking found

| Service | Free forever? | Limits |
|:--|:--|:--|
| Cosmos DB | **Yes** — "for the life of one Azure Cosmos DB account per Azure subscription" | 1,000 RU/s, 25 GB |
| Azure Functions | **Yes** | 1M requests/month |
| **Blob Storage** | **No free allowance found** | — |

Two caveats on the record: Cosmos's own FAQ contradicts its headline (400
RU/s and 5 GB against 1,000 and 25 GB), and the Functions free grant
"applies to paid, consumption subscriptions only" while every Function app
creates a storage account **not** covered by it.

And the sentence that decides this ADR:

> "If you don't [move to pay as you go within 30 days], your account and
> services will be disabled."

Nothing on Azure's pages states whether data survives that.

### Which kills the original argument

Blob Storage was the entire case for Azure here. Without a confirmed free
allowance it does not remove the cost of storing files — it moves the bill
from Google to Microsoft. Firestore's free tier already covers a
four-person rota, and it has the offline persistence that ADR-003 leans on
when it says *"we do not build a second one on top"*.

Replacing Firebase would cost the write queue and save nothing.

## Decision

**Azure enters as a spike behind a seam, and the app must work identically
without it.**

Three terms, and the third is the one that matters:

1. **A new `RemoteFiles` seam**, alongside the `RemoteFamilySource` that has
   been empty since Day 7. An Azure Function validates the Firebase ID
   token and returns a short-lived SAS URL; the phone uploads straight to
   Blob. No Azure credential ever ships in the app.

2. **The family's data does not move.** Firestore keeps the document.
   Cosmos DB is not adopted, free tier or not, because the offline queue is
   the expensive part and Firestore does it already.

3. **Nothing may depend on it.** Files are stored on the device first and
   uploaded opportunistically. If the credit lapses, the Function is gone,
   or the network is absent, the app behaves exactly as it does today —
   files on this phone, not shared. **That is not a degraded mode bolted on
   afterwards; it is the current behaviour, left in place, with sync added
   on top.**

## Why term 3 is written down rather than assumed

A spike that quietly becomes load-bearing is how a family app stops working
on day 31 of a 30-day credit. The failure would not be loud: photographs
would simply stop appearing, and the cause would be a trial that expired
three weeks earlier.

So the fallback is not a nicety. It is the thing being built, and the Azure
path is the addition.

**The test for this is behavioural, not architectural**: the suite runs with
no `RemoteFiles` at all, and every feature passes. If a test ever needs
Azure to be present, term 3 has been broken.

## What this is actually for

Two honest reasons, and they are different:

- **It might unblock files**, if the pricing turns out to be small enough
  once the real numbers are visible. That is unverified — the per-GB figure
  renders as a placeholder on Azure's own pricing page.
- **It is a month of real Azure**: Functions, Blob, and federating a
  Firebase identity into a SAS token. The owner asked for Azure in the
  project, and this is the version that teaches it without betting the
  family's rota on a trial credit.

## Consequences

**ADR-010 stands.** Its third clause forbids file uploads *that the app
depends on*. Nothing here is depended on, and the clause is not superseded
— if the spike is adopted, that will be its own ADR with its own numbers.

**A second cloud is a real cost** even at £0: two consoles, two credential
stores, two status pages, for an app one person maintains in the evenings.
Accepted knowingly and for a month.

**When the credit lapses**, the expected action is to delete the resource
group and remove the Function URL from the config. The app should need no
code change for that, and if it does, term 3 was not honoured.
