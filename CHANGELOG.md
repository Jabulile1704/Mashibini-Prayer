# Changelog

What changed, written for the family rather than for whoever wrote it.
Versions follow [Semantic Versioning](https://semver.org); the process is in
[docs/RELEASING.md](docs/RELEASING.md).

## [1.0.0] — 2026-10-30

The first release. The app knows whose week it is to lead family prayer, and
keeps knowing without anybody having to tell it again.

### The rota

- **Whose week it is**, on opening the app, with the date it hands over and
  who is next.
- **Set it up once** — everyone who takes a week, the order, which day the
  week turns over, and whose week it is right now. The app carries on from
  where the family already is rather than starting from scratch.
- **The weeks ahead**, eight of them, with dates and names.
- **Skip somebody's week** when they are away. The week passes to the next
  person and everyone moves up; nobody is owed a double turn later. It can be
  undone.
- **Add or remove someone** without disturbing weeks that have already
  happened. Changes take effect at the next turnover, never mid-week.

### Each day

- **A verse**, the same one for everybody on the same day, chosen from 75
  bundled passages. No internet needed.
- **A prayer journal** — one entry per day, kept on the phone and sent
  nowhere. What you are part-way through writing survives the phone closing
  the app.

### Reminders

- **The evening before your week starts**, if you switch it on. Off until you
  do, and this phone only reminds you — it cannot reach anybody else's phone.

### Throughout

- Works with no signal. Everything is kept on the phone and nothing is waited
  for.
- Dates read the South African way — Sunday, 1 November 2026.
- Text scales to the largest accessibility size without anything being cut
  off, and every control has a name a screen reader reads aloud.
- The version is at the foot of the home screen, so you can tell which build
  you have.

### Known limits

- **Phones do not yet see each other.** Each phone keeps its own copy of the
  rota. Everything needed to merge two copies is built and tested, but
  nothing is syncing yet.
- **The app cannot notify the whole family** when a week turns over. Sending
  a push needs a server, and the free Firebase plan has nowhere to run one.
  Each phone can remind its own owner, which it does.
- **An iPhone build installed from a free Apple account stops working after
  seven days** and has to be installed again. That is Apple's rule, not the
  app's.
