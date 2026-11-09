# Day 26 — Signing in, and a question twenty-four days overdue

**Date:** 2026-11-09 · **Phase:** 9, the v1.1 backlog · **Roles on point:** Developer, PO

## Planned

#76, sign-in — established yesterday as the thing #75 cannot be built
without.

## Delivered

- **Q3 answered and closed** (ADR-023), open since Day 2
- `Identity`, a seam over Firebase Auth with Google as the only provider
- `FamilyEditor.linkUid`, `unlinkUid`, `memberFor`
- A Settings row that signs in and ties the account to a person
- 710 tests, up from 688

## The question that had to be answered first

`DATA-MODEL.md` said, on Day 2:

> **Q3: does each member sign in as themselves, or does the family share
> one install?** … the decision is genuinely needed by Day 7.

It was needed on Day 26. Nothing forced it for nineteen days past its own
deadline, and the reason is instructive: **Q3 changes exactly one feature.**
The rota, the cycles, the skips, the verse, the tree and the songbook all
work identically either way. A question with a narrow blast radius can stay
open a very long time without anybody being stopped by it.

What finally forced it was Day 25 — the rules require an authenticated
caller, so sync needs sign-in, and sign-in needs to know whose.

The owner's answer: **each person signs in as themselves, and the journal
syncs privately.** The alternative was simpler and its cost was written down
on Day 2 — R4.2 unenforceable, journals device-only forever, and "the
privacy claim in the UI reduced to match". The app currently tells people
their journal is private; walking that back is worse than asking them to
sign in once.

## Two rules that look like details and are not

### A uid belongs to exactly one person

`linkUid` **refuses** an account already on another member rather than
moving it.

Moving it is the tempting behaviour — it looks like helpfulness. But two
members sharing one uid makes R4.2 unenforceable for exactly the reason the
shared-account option did, and the overwhelmingly likely cause of a
collision is somebody picking the wrong name on a phone. Silently
reassigning would hand one person another's journal.

The error says **whose** account it is, because that is what makes the
mistake fixable rather than merely refused.

### Signing out is not unlinking

Two things that look alike:

| | What it means | What it does |
|:--|:--|:--|
| Sign out | this phone is not holding your account | nothing to the family |
| Unlink | the wrong name was picked | removes the uid |

If signing out unlinked, one person signing out on a borrowed phone would
drop themselves from `memberUids` and **stop every other phone syncing
their changes**. The damage would land on people who did nothing.

Both are asserted, and the sign-out dialog says it before asking.

## Sign-in and linking are one action

An account with no member attached puts nobody in `memberUids`, which is
the field every rule reads. So signing in without linking would *look* like
it worked and sync nothing — the quiet kind of failure this project keeps
finding.

So the row refuses to start before "which one are you" has an answer, and
says why. It is the same shape as the songbook's add button, which will not
offer itself before the app knows who is choosing.

## What is not done

**Journal sync**, which the owner also asked for today. It is a separate
piece of work and deliberately not bundled: the journal is the one thing
whose privacy is now enforceable rather than aspirational, which makes it
the one thing worth getting wrong slowly. Filed rather than started.

**Signing in has not been run on a device.** The seam is tested with a fake
and the domain rules are tested properly, but Google sign-in on iOS needs
the URL scheme added today to be exercised against the real sheet, and that
cannot happen in a widget test. The first real sign-in is the first real
test of it, which is worth saying plainly rather than implying this is
finished.

## Tomorrow

#75 at last, now that there is an authenticated identity and the rules
accept the document the app writes.
