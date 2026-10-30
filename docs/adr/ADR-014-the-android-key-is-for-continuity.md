# ADR-014 — The Android key exists for update continuity, not provenance

**Status:** Accepted · **Date:** 2026-10-30 · **Deciders:** Owner, DevOps
**Supersedes:** part of [ADR-013](ADR-013-releases-are-tags-and-are-not-signed.md)

## Context

ADR-013, written this morning, said release builds are not signed for
distribution and explained why: no App Store, no TestFlight, no paid Apple
account, four users in one house. A key generated in CI would look like
provenance and carry none.

That reasoning is still right. It was also incomplete, and the gap showed up
within hours of v1.0.0 reaching a family member's Android phone.

## What was missed

An Android signature does two different jobs, and ADR-013 only considered
one of them.

**Provenance** — proving who built it. Worthless here, as ADR-013 argued.

**Continuity** — letting Android recognise the next build as the same app.
Android identifies an app by package name *and* signing key. A build signed
by a different key cannot be installed over the previous one; it fails with
`INSTALL_FAILED_UPDATE_INCOMPATIBLE`, and the only way through is to
uninstall first.

Everything in this app is device-local (ADR-003, ADR-006). Uninstalling takes
the rota, the prayer journal and the reminder settings with it.

The v1.0.0 artifact was signed with the Android debug key — confirmed by
reading the APK signing block, not assumed:

```
subject= /CN=Android Debug/O=Android/C=US
```

A CI runner has no debug keystore, so the Android Gradle Plugin generates
one. The distinguished name is fixed; the key material is not. **Every
release would have been signed by a different key**, and nobody would have
found out until the second one.

## Decision

**A stable release key, held in repository secrets, whose stated purpose is
continuity.**

- `signingConfigs.release` reads `android/key.properties` locally or the
  environment in CI. Absent, release builds fall back to the debug key so
  `flutter run --release` still works on a developer's machine.
- `release.yml` **fails** when the secrets are missing rather than falling
  back. A silent fallback would reintroduce exactly this bug, invisibly.
- The release job prints the signing certificate's owner and SHA-256, so the
  fingerprint can be compared across releases without downloading anything.
  The fingerprint is public; the key is not.
- The keystore is PKCS#12, generated with openssl rather than `keytool`,
  because there is no JDK on the development machine and the format is the
  same either way.

**The description stays honest.** This key says "the same thing built this"
and nothing more. Nobody verifies it, no installer checks it against
anything, and a release is still not a signed build in the sense an app store
means. ADR-013's argument survives; its conclusion was too broad.

## Consequences

**The key must not be lost.** Losing it means no phone with the app installed
can ever update in place again — everyone uninstalls and starts over, losing
their journals. It lives in repository secrets and should also live wherever
the owner keeps things they cannot replace. RELEASING.md says so and says
what to do if it happens anyway.

**v1.0.0 cannot be updated in place.** It is already on a phone, signed with a
throwaway debug key that no longer exists anywhere. That install has to be
removed before v1.1.0 will install. One uninstall, once, and never again —
and the rota takes a minute to set up because this was caught at one install
rather than at twenty.

**Four phones, one key.** There is no key rotation story and does not need to
be one; if the app is ever distributed more widely, that is the moment to
revisit, and this ADR gets superseded rather than edited.
