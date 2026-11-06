import 'package:flutter/material.dart';

import '../../data/repositories/device_settings_repository.dart';
import '../../data/repositories/family_repository.dart';
import '../../data/repositories/journal_repository.dart';
import '../../data/sources/notifications/reminders.dart';
import '../../data/sources/platform/app_version.dart';
import '../../data/sources/platform/photos.dart';
import '../../data/sources/platform/sharing.dart';
import '../../domain/entities/calendar_date.dart';
import '../../domain/ids.dart';
import '../widgets/comb_bar.dart';
import 'family_tree_screen.dart';
import 'journal_screen.dart';
import 'schedule_screen.dart';
import 'settings_screen.dart';
import 'this_week_screen.dart';

/// The five tabs, and the comb that moves between them (ADR-016, ADR-020,
/// ADR-022).
///
/// Before this, every destination in the app was a `Navigator.push` from
/// This Week, three of them from icon buttons in the top-right — the hardest
/// place on a phone to reach one-handed and the easiest to miss. Day 13's
/// accessibility pass gave those icons screen-reader names; a name does not
/// make an unlabelled icon discoverable to somebody looking at the screen.
///
/// ADR-016 set four as the ceiling, and **Family is the fifth** (#109). That
/// was a deliberate reversal rather than an oversight: ADR-020 records who
/// asked, what the ADR's reasoning was worth on inspection, and what had to
/// be checked before it could be added — five labels at the largest text
/// size being the actual risk, not the count.
///
/// Five is the ceiling now, and this time it is the platform's. Material's
/// `NavigationBar` takes three to five destinations; a sixth needs a
/// different kind of navigation, not one more icon.
class HomeShell extends StatefulWidget {
  const HomeShell({
    required this.repository,
    required this.settings,
    required this.journal,
    required this.sharing,
    required this.reminders,
    required this.appVersion,
    required this.photos,
    required this.ids,
    this.today,
    super.key,
  });

  final FamilyRepository repository;
  final DeviceSettingsRepository settings;
  final JournalRepository journal;
  final Sharing sharing;
  final Reminders reminders;
  final AppVersion appVersion;
  final Photos photos;
  final IdGenerator ids;
  final CalendarDate Function()? today;

  static const Key bar = Key('shell.bar');

  /// Where the raised comb cell sits: the middle of five.
  static const int centre = 2;

  /// The five destinations, in the order they appear.
  ///
  /// **This week is in the middle**, not first, and is the raised cell. The
  /// app answers one question and the bar should look like it does — see
  /// ADR-022.
  ///
  /// Every label is **one word** except the centre's, which is not drawn.
  /// Five labels share the width of a phone, and "Weeks ahead" wrapped onto
  /// two lines, which pushed its icon up and left the row ragged. "Ahead"
  /// beside a centre cell meaning this week is not ambiguous; it is the
  /// same distinction in half the space.
  static const List<CombDestination> destinations = <CombDestination>[
    CombDestination(
      icon: Icons.event_outlined,
      selectedIcon: Icons.event,
      label: 'Ahead',
    ),
    CombDestination(
      icon: Icons.menu_book_outlined,
      selectedIcon: Icons.menu_book,
      label: 'Journal',
    ),
    CombDestination(
      icon: Icons.hexagon_outlined,
      selectedIcon: Icons.hexagon,
      label: 'This week',
    ),
    CombDestination(
      icon: Icons.groups_outlined,
      selectedIcon: Icons.groups,
      label: 'Family',
    ),
    CombDestination(
      icon: Icons.tune_outlined,
      selectedIcon: Icons.tune,
      label: 'Settings',
    ),
  ];

  /// The five labels, in order. For the accessibility sweep.
  static List<String> get labels => <String>[
    for (final CombDestination d in destinations) d.label,
  ];

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  /// Opens on This week.
  ///
  /// It is the middle destination now rather than the first, and the app
  /// exists to answer the question that screen answers — so the index is
  /// named rather than left as a 0 that used to mean the same thing by
  /// accident.
  int _tab = HomeShell.centre;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // IndexedStack rather than swapping the body, so each tab keeps its
      // state: a half-scrolled journal is still half-scrolled when somebody
      // checks whose week it is and comes back. Rebuilding would also
      // re-read storage on every switch, which is the kind of thing that
      // makes an app feel slow for no reason anybody can name.
      body: IndexedStack(
        index: _tab,
        children: <Widget>[
          // In `HomeShell.destinations` order, which puts This week third.
          ScheduleScreen(
            familyRepository: widget.repository,
            settings: widget.settings,
            ids: widget.ids,
            today: widget.today,
          ),
          JournalScreen(journal: widget.journal, today: widget.today),
          ThisWeekScreen(
            repository: widget.repository,
            settings: widget.settings,
            ids: widget.ids,
            today: widget.today,
          ),
          FamilyTreeScreen(
            familyRepository: widget.repository,
            photos: widget.photos,
            ids: widget.ids,
            today: widget.today,
          ),
          SettingsScreen(
            familyRepository: widget.repository,
            settings: widget.settings,
            journal: widget.journal,
            sharing: widget.sharing,
            reminders: widget.reminders,
            appVersion: widget.appVersion,
            ids: widget.ids,
            today: widget.today,
          ),
        ],
      ),
      bottomNavigationBar: CombBar(
        key: HomeShell.bar,
        destinations: HomeShell.destinations,
        centreIndex: HomeShell.centre,
        selectedIndex: _tab,
        onSelected: (int to) => setState(() => _tab = to),
      ),
    );
  }
}
