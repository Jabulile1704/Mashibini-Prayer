# Requirements — Mashibini Prayer v1.0

Status: **baselined** at Day 1. Changes after this point go through the change
log at the bottom, so the history shows what moved and why.

Each story carries an ID, a priority (MoSCoW) and acceptance criteria written as
Given/When/Then. A story is not "done" until every one of its criteria has a
passing test or a QA sign-off recorded on the issue.

---

## Glossary

| Term | Meaning |
|:--|:--|
| **Member** | One person in the family rota |
| **Cycle** | The ordered list of members, repeating forever |
| **Turn** | One member's week of leading prayer |
| **Turnover day** | The weekday a turn hands over to the next member |
| **Anchor date** | The real date a known turn began; every later turn is counted from it |
| **Skip** | A turn deliberately passed over, keeping the cycle's rhythm intact |

---

## E1 — The rota

The core of the product. If only this epic shipped, the app would still be worth
installing.

### R1.1 — See whose week it is `MUST`

**As** a member, **I want** to open the app and see whose week it is, **so that**
nobody has to ask.

- **Given** a cycle of four members and an anchor date, **when** I open the app,
  **then** the current leader's name is the most prominent thing on the screen.
- **Given** the current leader is me, **when** I open the app, **then** it says so
  in the second person ("It's your week"), not by my own name.
- **Given** the app has never had a network connection, **when** I open it,
  **then** the current leader still resolves correctly from the stored anchor.

### R1.2 — See who is next, and when it changes `MUST`

- **Given** a cycle, **when** I look at the home screen, **then** I see who takes
  the next turn and the date it starts.
- **Given** the turnover is today, **when** I open the app, **then** the new
  leader is shown — the handover takes effect at the start of the turnover day,
  not at an arbitrary hour.

### R1.3 — The cycle never drifts `MUST`

- **Given** an anchor date and a turnover weekday, **when** any future date is
  evaluated, **then** the leader is derived by counting whole weeks from the
  anchor, never by adding seven days repeatedly to a running total.
- **Given** the device's clock or timezone changes, **when** the app recomputes,
  **then** the answer is unchanged for the same calendar date in the family's
  timezone.
- **Given** the app is not opened for six months, **when** it is opened again,
  **then** the leader is correct for that day without any catch-up work.

### R1.4 — Skip a turn `SHOULD`

- **Given** a member is away, **when** their turn is skipped, **then** the next
  member leads that week and the cycle order is otherwise unchanged.
- **Given** a turn was skipped, **when** the cycle comes around again, **then**
  the skipped member is not owed a double turn — a skip is forgiveness, not debt.

### R1.5 — See the cycle ahead `COULD`

- **Given** a cycle, **when** I ask for the schedule, **then** I see the next
  eight turns with their dates and leaders.

---

## E2 — Family setup

### R2.1 — Define the family `MUST`

- **Given** a first run, **when** I add members, **then** each has a display name
  and a position in the cycle.
- **Given** fewer than two members, **when** I try to finish setup, **then** the
  app explains that a rota needs at least two people.

### R2.2 — Set the turnover day and anchor `MUST`

- **Given** setup, **when** I choose the turnover weekday and say whose turn the
  current week is, **then** the app derives and stores the anchor date from that
  answer, so I never have to understand what an anchor is.

### R2.3 — Change the family later `SHOULD`

- **Given** an established cycle, **when** a member is added, **then** they join
  at the end of the order and no current or past turn is reassigned.
- **Given** an established cycle, **when** a member is removed, **then** past
  turns still display their name, and only future turns are affected.

---

## E3 — Daily verse

### R3.1 — A verse for the day `SHOULD`

- **Given** any day, **when** I open the app, **then** one verse is shown for
  that date, and it is the same verse for every member of the family.
- **Given** no network, **when** I open the app, **then** a verse is still shown
  from the bundled set.

### R3.2 — Attribution and licensing `MUST`

- **Given** any verse shown, **when** it is displayed, **then** the translation is
  named, and only a translation whose licence permits redistribution is bundled.

---

## E4 — Prayer journal

### R4.1 — Write an entry `SHOULD`

- **Given** any day, **when** I write an entry, **then** it is saved with its date
  and survives the app being closed.

### R4.2 — Entries are private `MUST`

- **Given** an entry I wrote, **when** another member opens their app, **then**
  they cannot read it — not in the UI, and not in the database.

### R4.3 — Find an old entry `COULD`

- **Given** entries over time, **when** I look back, **then** they are listed
  newest first and grouped by month.

---

## E5 — Reminders

### R5.1 — Handover reminder `SHOULD`

- **Given** a turnover tomorrow, **when** the reminder time arrives, **then** the
  incoming leader is told their week starts tomorrow.
- **Given** reminders have never been enabled, **when** the app is installed,
  **then** it sends nothing until asked — an app that starts notifying uninvited
  is not a good houseguest.

---

## E6 — Sync and offline

### R6.1 — Offline read `MUST`

- **Given** no connection, **when** I open the app, **then** the rota, today's
  verse and my own journal entries are all readable.

### R6.2 — Converging writes `SHOULD`

- **Given** two members change the cycle while offline, **when** both reconnect,
  **then** the result is deterministic and the losing change is not silently
  discarded.

---

## Non-functional requirements

| ID | Requirement | How it is verified |
|:--|:--|:--|
| N1 | Cold start to the rota answer in under 2 seconds on a mid-range Android | Manual timing on a real device, recorded in the test log |
| N2 | The rota is computed by pure Dart with no I/O, so it is testable without a device | Unit tests run in CI with no emulator |
| N3 | Journal entries are readable only by their author, enforced in the database, not only the UI | Firestore rules unit tests |
| N4 | Only data the app needs is collected: names, cycle positions, journal text. No contacts, no location, no analytics on individuals | Data model review, documented in DATA-MODEL.md |
| N5 | Text scales with the OS setting without clipping, and every control has a label a screen reader can read | Accessibility pass before release |
| N6 | Every merge to `develop` is analysed, tested and built by CI from a clean checkout | GitHub Actions, required status check |
| N7 | The app's state survives being killed by the OS mid-session | Manual test case in the release checklist |

---

## Assumptions

1. All four members have a smartphone capable of running a current Flutter app.
2. The family's timezone is Africa/Johannesburg (UTC+2, no daylight saving).
3. The rota is weekly and the same length for everyone — no half-weeks.
4. A Firebase project on the free tier is sufficient for four users.

## Open questions

| # | Question | Owner | Needed by |
|:--|:--|:--|:--|
| ~~Q1~~ | ~~Which weekday does the family's week actually turn over on?~~ **Closed Day 6: the setup screen asks. The weekday is a required answer and the app stores whichever one the family chooses; the picker merely opens on Sunday as a starting position.** | Stakeholder | — |
| ~~Q2~~ | ~~Which Bible translation may be bundled and redistributed?~~ **Closed Day 10: the World English Bible, British Edition (WEBPB). Public domain by explicit dedication, no required attribution, one trademark condition — do not call it the WEB if you change the text. See ADR-009.** | PO + Developer | — |
| Q3 | Do members sign in individually, or is it one shared family install? | PO | Day 7 (auth) |
| Q4 | Should the journal ever be shareable with the family by choice? | PO | Post-v1 |

## Change log

| Date | Change | Reason |
|:--|:--|:--|
| 2026-10-19 | Baselined at v1.0 scope | Day 1 inception |
| 2026-10-23 | Q1 closed without an answer being needed | Day 6: setup asks the family rather than the project assuming |
| 2026-10-27 | Q2 closed: WEBPB, public domain | Day 10: owner chose the WEB; the edition was chosen for "The LORD" over "Yahweh" and British spelling |
