# Architecture Decision Records

One file per decision that will make someone ask "why is it like this?".

Format: context, decision, consequences — including the ones we did not like.
An ADR is never edited once accepted; it is superseded by a later one that
names it.

| # | Decision | Status |
|:--|:--|:--|
| [001](ADR-001-flutter-and-firebase.md) | Flutter and Firebase | Accepted |
| [002](ADR-002-derive-turns-from-an-anchor.md) | Derive turns from an anchor date | Accepted |
| [003](ADR-003-offline-first-read-path.md) | Local store is the read path | Accepted |
| [004](ADR-004-journals-outside-the-family-tree.md) | Journals keyed by author, outside the family tree | Accepted |
| [005](ADR-005-a-calendar-date-type.md) | A CalendarDate type, not DateTime | Accepted |
| [006](ADR-006-a-key-value-store-not-a-database.md) | A key-value store for the family, not a database | Accepted |
| [007](ADR-007-develop-is-default-and-prs-rebase.md) | `develop` is the default branch, and PRs rebase | Partly superseded by 015 |
| [008](ADR-008-merging-is-a-union-of-append-only-logs.md) | Merging is a union of append-only logs | Accepted |
| [009](ADR-009-the-verses-are-bundled-webpb.md) | The verses are bundled, and they are the WEBPB | Superseded by 025 |
| [010](ADR-010-the-free-tier-is-a-design-constraint.md) | The free tier is a design constraint, not a billing preference | Accepted |
| [011](ADR-011-the-firebase-config-is-committed.md) | The Firebase config is committed to a public repository | Accepted |
| [012](ADR-012-a-skip-is-withdrawn-not-deleted.md) | A skip is withdrawn, never deleted | Accepted |
| [013](ADR-013-releases-are-tags-and-are-not-signed.md) | A release is a tag, and it is not signed for distribution | Partly superseded by 014 |
| [014](ADR-014-the-android-key-is-for-continuity.md) | The Android key exists for update continuity, not provenance | Accepted |
| [015](ADR-015-releases-cherry-pick-back-to-develop.md) | The release goes back to `develop` as a cherry-pick, not a merge | Partly superseded by 018 |
| [016](ADR-016-four-tabs-and-what-goes-in-them.md) | Four tabs, and what goes in each | Accepted, amended by 020 and 022 |
| [017](ADR-017-the-identity-is-the-family-totem.md) | The identity is the family's totem: honey, ink and a comb | Accepted |
| [018](ADR-018-release-branches-are-cut-from-main.md) | Release branches are cut from `main` | Accepted |
| [019](ADR-019-the-turnover-day-is-an-epoch-not-a-setting.md) | The turnover day is an epoch, not a setting | Accepted |
| [020](ADR-020-a-fifth-tab-and-what-four-was-worth.md) | A fifth tab, and what "four is the ceiling" was worth | Accepted |
| [021](ADR-021-the-tree-is-not-the-rota.md) | The tree is not the rota, and photographs stay on the phone | Accepted |
| [022](ADR-022-the-centre-of-the-bar-is-a-comb-cell.md) | The centre of the bar is a comb cell | Accepted |
| [023](ADR-023-each-person-signs-in-as-themselves.md) | Each person signs in as themselves (closes Q3) | Accepted |
| [025](ADR-025-the-daily-reading-is-an-african-saying.md) | The daily reading is an African saying, not a Bible verse | Accepted |
