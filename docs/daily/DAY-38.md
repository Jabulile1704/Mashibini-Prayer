# Day 38 — The only phone the free tier can reach

**Date:** 2026-11-23 · **Phase:** 9, the v1.1 backlog · **Roles on point:** Developer, Product Owner

> The second of two days in one sitting, as Days 29 and 30 were. The date is
> honest; the day number counts the work.

## Planned

#77 — the last open story, and the one the free tier forbids.

## Delivered

- **#165** — the outgoing leader is told who is next, so they can say so
- 8 tests, and 5 existing ones updated because the contract genuinely moved
- R5.1's scope widened, with what it still does **not** reach named
- 884 tests, up from 875

**#77 stays open.** It is not work, it is a decision, and the decision costs
money.

## What #77 wants and cannot have

> Somebody who never opens the app and never switches reminders on is told
> nothing.

Sending a push to another person's phone needs a sender in a trusted
environment. Spark has no Cloud Functions to host one (ADR-010).

And it is worth saying that **v2.2.0 did not change this**, because it looks
as though it should have. A Firestore document arriving on a phone is not a
notification. Sync means every phone *knows* the rota; it gives none of them
the ability to make another one ring.

So #77 needs a paid plan or a nominated device volunteering to be the
sender. Both are the owner's call, and neither is a thing to be built
quietly on a Monday.

## What the free tier does allow

There is exactly one phone the app can rely on being in use: **the person
leading prayer this week has been opening it all week.** That phone is
reachable, and the person holding it is the one with a reason to speak to
whoever is next.

So, on the evening their week ends:

> **Your week ends tomorrow**
> Sisi leads family prayer from tomorrow. Worth telling them.

It routes the handover through a person, which is how the family handed over
before there was an app. The Settings copy says that plainly rather than
implying anybody else was reached:

> This phone reminds you, and only you. On your last evening it names
> whoever is next, so you can tell them.

**It is not a fix for #77**, and R5.1 now says so: it reaches the
*outgoing* leader, so if that person has reminders off it reaches nobody —
the same gap, one person along. What it buys is that the gap needs **one**
member to have reminders on instead of all four, and that member is
self-selecting.

## Two details that earned their tests

**The next leader comes from the engine, not the cycle order.** A skipped
week means the person after you in the list is not the person who leads.
Naming the wrong one is worse than naming nobody, so there is a test with a
skip in it.

**The ids are offset.** Both kinds derive from a date, and a repeated
notification id means one reminder silently replaces another — the quietest
possible failure. A test plans for all four members and asserts every id is
distinct and fits in a 32-bit int, which is what a notification id has to
be.

## The suite earned its keep twice

This is the part worth keeping.

**The horizon changed meaning and I did not notice.** It has always meant
"this many reminders actually scheduled", so a turn whose evening has
already gone must not consume one of them. I moved the counter to count
*turns* instead, which is the obvious reading of the word, and
`the horizon is still filled after skipping a passed one` went red.

That test was written on Day 12 for a different reason, and it caught a
behaviour change three weeks later that nothing else would have. The line
now carries a comment saying why it is where it is.

**And a settings assertion was pinning stale wording** — the shape Day 36
recorded. Mid-week, the soonest reminder is now the handover rather than a
turn four weeks out, so `Next: the evening before` no longer appeared. The
temptation is to loosen the matcher. Instead the test is specific about the
mid-week case and a second test covers the other, which says more than
either did before.

Five existing tests were updated in total. Each still asserts what it
originally meant: `own(...)` filters to the reminders about a week you lead,
which is what every test written before today meant by "the plan".

## Open

- **#77** — a paid plan, a nominated sender, or close it as won't-fix. The
  only open issue, and the only one that is a decision rather than work.
- **v2.2.0 unpublished.** Blocked on a service-account key that has never
  downloaded; the console may be refusing to create one, which would mean
  five failed attempts were a wrong instruction rather than a missed click.
- **The journal does not sync**, and the rota now does.
- **Two real phones.** Still the only test of #75 that counts.
- **Q5** — nobody fluent has checked the sayings' spelling.
