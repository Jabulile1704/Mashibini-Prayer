# SDLC — how this project is run

The app is small. The process is not, deliberately: the point of this project is
to practise building software the way a team does, with every phase visible in
the repository rather than in somebody's head.

## Phases, and where each one lives

| Phase | Produces | Where it lives |
|:--|:--|:--|
| **1. Inception & planning** | Charter, scope, roles, plan | `docs/CHARTER.md`, this file, the project board |
| **2. Requirements** | Stories with acceptance criteria, NFRs, open questions | `docs/REQUIREMENTS.md`, issues labelled `type:story` |
| **3. Design** | Architecture, data model, security rules, decisions | `docs/ARCHITECTURE.md`, `docs/DATA-MODEL.md`, `docs/adr/` |
| **4. Implementation** | The app | `lib/`, one feature branch per story |
| **5. Testing** | Test strategy, automated tests, defect log | `docs/TEST-STRATEGY.md`, `test/`, issues labelled `type:defect` |
| **6. Deployment** | Pipelines, release artifacts, tags | `.github/workflows/`, GitHub Releases |
| **7. Maintenance** | Retrospective, backlog for v1.1 | `docs/RETROSPECTIVE.md`, milestone `v1.1` |

The phases overlap — testing starts on Day 3, not Day 11 — but each one has a
named artifact that has to exist before the phase is called complete.

## The 15-day plan

One working day per row. Each day ends with something merged into `develop`;
a day that merges nothing is a day that has to explain itself in the log.

**This plan was fourteen days and is now fifteen.** The original had no design
day at all: Day 2's "design" is architecture, and Day 13's hardening is
accessibility. Nothing anywhere scheduled an icon, a splash or a considered
look — so on Day 7 the app still shipped Flutter's default logo and a stock
Material card, which the owner noticed before the plan did.

Day 8 was inserted rather than appended, because the verse and the journal land
on Days 10 and 11 and it is far cheaper to decide what the home screen *is*
before filling it than to retrofit a layout around three features that were
each added on their own.

| Day | Phase | Deliverable | Role on point |
|:--:|:--|:--|:--|
| 1 | Inception | Charter, requirements baseline, backlog, board, branch protection, CI skeleton, app scaffold | PM, PO, DevOps |
| 2 | Design | Architecture, data model and ERD, Firestore schema, ADRs 1–3 | DBA, Developer |
| 3 | Implementation | Cycle engine: whose week is it, pure Dart, fully unit tested (R1.1, R1.3) | Developer, QA |
| 4 | Implementation | Persistence and repository abstraction, fakes for tests (R6.1) | DBA, Developer |
| 5 | Implementation | Home screen: this week, next week, handover date (R1.1, R1.2) | Developer |
| 6 | Implementation | Family setup: members, order, turnover day, anchor (R2.1, R2.2) | Developer, PO |
| 7 | Implementation | Firebase: project, auth decision, Firestore wiring (R6.2) | DevOps, DBA |
| 8 | Design | The mark, the app icon, the splash, and the home screen as a designed thing | Developer, PO |
| 9 | Security | Firestore security rules and their tests (N3, R4.2) | DBA, QA |
| 10 | Implementation | Daily verse, bundled and licensed (R3.1, R3.2) | Developer |
| 11 | Implementation | Prayer journal, private by construction (R4.1, R4.2) | Developer, DBA |
| 12 | Implementation | Handover reminders, opt-in (R5.1) | Developer |
| 13 | Hardening | Skip a turn (R1.4), offline states, accessibility pass (N5, N7) | QA |
| 14 | Deployment | Release branch, version bump, changelog, signed build, tag v1.0.0 | DevOps |
| 15 | Closure | Retrospective, metrics, v1.1 backlog | PM, PO |

## Working agreements

- **The board is the truth.** If work is happening, it has a card in **In progress**. One card in progress at a time.
- **Every day ends green.** `develop` always builds and passes its tests.
- **Decisions get written down.** Anything that will make someone ask "why is it like this?" becomes an ADR in `docs/adr/`.
- **Defects are issues, not notes.** Anything found and not fixed immediately is filed with steps to reproduce.
- **Scope is defended.** A new idea becomes a backlog item for v1.1; it does not quietly join v1.0.

## Daily log

Each day's work is summarised in `docs/daily/DAY-NN.md`: what was planned, what
was delivered, what moved on the board, and anything that blocked. The log is
written at the end of the day by the PM role, and it is the first thing to read
when picking the work up again.
