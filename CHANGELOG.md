# Changelog

What changed, written for the family rather than for whoever wrote it.
Versions follow [Semantic Versioning](https://semver.org); the process is in
[docs/RELEASING.md](docs/RELEASING.md).

## [2.0.0] — 2026-11-06

**The app stopped being something you set up once.** Nearly everything the
rota asked you at the beginning — who is in it, which day the week turns
over, which person you are — can be changed now without throwing the rota
away. And there is a new tab for the family itself.

### New

- **A Family tab.** Everyone in the family as a honeycomb, with a photograph
  and a word for each person — *Mama*, *eldest sister*, *born 2019*, whatever
  your family says. Say who somebody's parents are and the comb arranges
  itself into generations. **Adding somebody here does not give them a week
  of prayer**: the tree is everybody, the rota is who leads, and they are not
  the same list. Photographs stay on this phone — they are never sent
  anywhere, which also means the others cannot see them, and reinstalling the
  app loses them.
- **Add and remove people from the rota**, from Settings. Before this, the
  only way was to start the whole rota again, which threw away the order, the
  turnover day and every week anybody had skipped. Changes start at the next
  turnover and this week is never altered, so nobody's week changes under
  them.
- **Change the day the week turns over.** Also from Settings, and it tells
  you what will happen before you agree to it: the date it starts, whose week
  gets shortened and by how many days, and who takes the first full week.
  Weeks that have already happened keep whoever led them.
- **Keep a copy of your journal.** Sends the whole thing to yourself as plain
  text. Worth doing: reinstalling the app loses what is not kept.
- **Skipping a week now says so**, with an Undo in the message. It used to
  rearrange the list in silence.

### Better

- **A new bottom bar.** *This week* sits in the middle now, raised out of the
  bar as a honey comb cell, because it is the question the app exists to
  answer. The other four sit either side with one word each — *Weeks ahead*
  was two words and wrapped onto two lines, which left the row looking
  uneven.

- Every screen uses the same spacing, so the tabs line up with each other.
- The empty screens offer the next thing to do instead of stopping. *The
  weeks ahead* now names the date the rota starts; the journal offers to
  write the first entry.

### Fixed

- A check that was supposed to prove each release is signed with the same key
  had been proving nothing for four releases. It now fails when it cannot
  read the key, which is what a check is for.

### A note on the version

This is **2.0.0** rather than 1.5.0 for one reason: the family is stored in a
new shape, and version 1.4.0 cannot read it. Nothing is lost going forward —
this version reads everything older perfectly — but a phone that installs
this cannot go back.

## [1.4.0] — 2026-11-04

**You can change your mind now.** Two things the app would only ask you
once — the order of the rota, and which person you are — can both be
changed whenever you like.

### New

- **Say which one you are, at any time.** The app asked this when you first
  set up the rota, and if you picked the wrong name there was no way back:
  the only fix was to start the whole rota again. It is a row in Settings
  now, and changing it moves your reminders with it.
- **Light, dark, or follow your phone.** The honey and the dark of the hive
  are the same colours in all three — honey is brightest against the dark
  and deepens against the cream, so it reads either way.
- **Setting up the rota is one list.** Before, you typed the names and then
  answered a second question about whose week it was, and that second answer
  quietly rearranged the first. Now each row says the week it covers — *this
  week*, *from Mon, 9 Nov* — and you drag people into the order you want.
- **An About page**, which says what the app does, that your journal never
  leaves your phone, and — plainly — the two things it still cannot do.

### Better

- **Reminders are one switch instead of a screen.** Turning them on used to
  mean opening a page to find a single control. The switch is in Settings,
  and it tells you the next reminder it is holding for you.
- **The day your week turns over is shown** in Settings. It could be set
  when you first made the rota and then never seen again.

### Not yet

You still cannot add or remove somebody, or change the turnover day, without
starting the rota again. Both are next.

## [1.3.0] — 2026-11-03

**The app has a bottom bar now.** Everything used to be behind three small
icons in the top corner; there are now four tabs, with their names written
on them.

### New

- **This week · Weeks ahead · Journal · Settings**, along the bottom. Each
  one remembers where you were — come back to the journal and you are
  where you left it, not at the top.
- **A Settings tab**, which gathers up the things that had no proper place:
  reminders, starting the rota again, and which version you are running.
- **The opening is one moment instead of three.** The honeycomb holds while
  the app reads your rota, then settles into it, rather than flashing
  through a loading spinner on the way.

### Better

- The honeycomb's cells were overlapping each other. They are now four
  separate cells, which is the point of them — one per person.

## [1.2.1] — 2026-11-02

Nothing in the app changed. This release exists to prove that releasing
works again: the previous two had to be assembled by hand because the
process had broken itself, and this is the first one in three that did not.

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
