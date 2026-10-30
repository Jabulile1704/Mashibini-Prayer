# ADR-013 — A release is a tag, and it is not signed for distribution

**Status:** Accepted · **Date:** 2026-10-30 · **Deciders:** Owner, DevOps

## Context

The owner intends to keep shipping this app to four phones, often. Day 14's
job was to release v1.0.0; the more useful job was to make release number
fifteen as cheap as release number one.

Two questions had to be answered: what *is* a release here, and what does it
mean for a build to be "signed" when there is no App Store on the other end.

## A release is a tag on `main`

`release.yml` fires on `v*` and nothing else. It refuses to publish if the
tag disagrees with `pubspec.yaml`, or if `CHANGELOG.md` has no section for
that version.

The alternatives were worse in the same way. A workflow fired by hand lets
somebody publish a build that was never tagged, and a release built on every
push to `main` makes the merge the decision rather than the tag — which means
there is no moment where somebody chooses to ship.

So: **no publishing without a tag, no tagging without publishing.** The tag is
the decision and everything else is consequence.

The version check is not ceremony. A tag that disagrees with `pubspec.yaml`
ships a build whose own version line contradicts the release it came from,
and the only place that would surface is somebody's phone, weeks later, while
trying to work out which build has the bug.

## It is not signed for distribution, and that is not a gap

"Signed build" is in the Day 14 acceptance criteria. It is not being done, so
the reasoning belongs here rather than in a commit message nobody will find.

This app has no App Store presence, no TestFlight, no paid Apple Developer
account, and four users who are all in one house. There is no distribution
channel for a signature to mean anything to.

Signing with a throwaway key generated in CI would produce something that
*looks* like provenance and carries none: the key would live in the workflow
run, nobody would hold the counterpart, and no installer anywhere would check
it. That is worse than being plainly unsigned, because it invites the belief
that the build was verified.

So the Android artifact is a release-shape APK with debug keys, attached to
the GitHub Release, and it is described as exactly that.

**iOS is installed by cable**, signed by the owner's free Apple account.
Free provisioning lasts **seven days**, after which the app refuses to open
until it is installed again. That is Apple's rule for accounts without a paid
membership, and the app can do nothing about it.

### What would change this

A paid Apple Developer membership, or distribution to anybody outside the
house. Either one makes a real signing identity worth having, and at that
point the key goes in repository secrets, `release.yml` gains a signing step,
and this ADR gets superseded rather than edited.

## Consequences

- Releasing is `tool/release.sh`, a PR, and a tag. Documented in
  `docs/RELEASING.md` on one page.
- The changelog is a required input, not an output. A version with nothing
  worth writing down is a version that did not need cutting.
- The build number climbs forever and never repeats, so two builds are never
  confusable on a phone even when they share a version.
- The app shows its own version, so the question "which build is this?" can be
  answered by looking at the phone rather than by plugging it into a Mac.
- Every seven days the iPhone build stops working. The family know; it is in
  RELEASING.md so the next person does not file it as a bug.
