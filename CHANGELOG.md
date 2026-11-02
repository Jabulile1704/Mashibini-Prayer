# Changelog

What changed, written for the family rather than for whoever wrote it.
Versions follow [Semantic Versioning](https://semver.org); the process is in
[docs/RELEASING.md](docs/RELEASING.md).

## [1.2.0] — 2026-11-02

### Changed

- **The week now runs Monday to Sunday.** Sunday is the last day you lead,
  and the next person starts on Monday morning. You can still choose any
  other day when you set the rota up — this is just what it offers first.

### New

- **You can set the rota up again.** Before this, once a rota existed there
  was no way back in to change who is in it, the order, or the day it turns
  over. The new control is in the top bar; it asks before replacing
  anything, and your journal is kept either way.

### Better

- The boxes you type names into look like something you can type into,
  rather than an outline drawn around nothing. The one you are using is now
  obvious at a glance.
- The keyboard's return key moves you to the next name instead of closing
  the keyboard, so entering four names takes four taps rather than eight.

## [1.1.0] — 2026-11-02

**The app now looks like the family it belongs to.** The Mashibini totem is
the bee, so the colours are a bee's — honey against a dark the colour of the
inside of a hive, on a ground the colour of wax.

### New

- **A new look, built on the totem.** Honey, ink and wax replace the old
  indigo and rust.
- **A new mark: a cluster of comb cells, one of them filled.** There is one
  cell per person in the rota, and the filled one is whose week it is — so
  the icon tells you something rather than just sitting there.
- **The bee colours survive light, dark and system.** Honey is brightest in
  dark mode, where it belongs; on the pale ground it deepens to amber so it
  stays readable. It is the same colour either way, never washed out.
- A new app icon and launch screen, drawn from the same mark.

### Behind the glass

- Every colour pair in the app is now checked for readability by a test, in
  both light and dark. It caught two things nobody could see: a version line
  that had been too faint to read since 1.0.0, and a divider in the new dark
  theme that was invisible the day it was written.
- Releases can be built again — the process broke itself after 1.0.1 and is
  fixed.

### Not yet

The screens have not been rearranged. Bottom navigation, a settings page and
a way to change who is in the rota are next.

## [1.0.1] — 2026-10-30

Nothing visible changed. **Install this one rather than 1.0.0** — it is the
first build Android will let you update in place.

### Fixed

- Android builds are now signed with a key that stays the same from one
  release to the next. Before this, every release carried a different key,
  and Android refuses to install a new version over an old one signed by a
  different key — the only way through would have been to uninstall, which
  takes that phone's rota and prayer journal with it.
- The release notes no longer list the whole project's history every time.

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
