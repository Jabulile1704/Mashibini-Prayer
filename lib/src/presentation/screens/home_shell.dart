import 'package:flutter/material.dart';

import '../../data/repositories/device_settings_repository.dart';
import '../../data/repositories/family_repository.dart';
import '../../data/repositories/journal_repository.dart';
import '../../data/sources/notifications/reminders.dart';
import '../../data/sources/platform/app_version.dart';
import '../../data/sources/platform/sharing.dart';
import '../../domain/entities/calendar_date.dart';
import '../../domain/ids.dart';
import 'family_tree_screen.dart';
import 'journal_screen.dart';
import 'schedule_screen.dart';
import 'settings_screen.dart';
import 'this_week_screen.dart';

/// The five tabs, and the bar that moves between them (ADR-016, ADR-020).
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
  final IdGenerator ids;
  final CalendarDate Function()? today;

  static const Key bar = Key('shell.bar');

  /// The five destination labels, in order.
  ///
  /// Exposed so the accessibility sweep measures the real list rather than a
  /// copy of it that can fall behind — which matters more than it sounds,
  /// because what that sweep measures is whether these words fit (#111).
  static const List<String> labels = <String>[
    'This week',
    'Weeks ahead',
    'Journal',
    'Family',
    'Settings',
  ];

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;

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
          ThisWeekScreen(
            repository: widget.repository,
            settings: widget.settings,
            ids: widget.ids,
            today: widget.today,
          ),
          ScheduleScreen(
            familyRepository: widget.repository,
            settings: widget.settings,
            ids: widget.ids,
            today: widget.today,
          ),
          JournalScreen(journal: widget.journal, today: widget.today),
          FamilyTreeScreen(
            familyRepository: widget.repository,
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
      bottomNavigationBar: NavigationBar(
        key: HomeShell.bar,
        selectedIndex: _tab,
        onDestinationSelected: (int to) => setState(() => _tab = to),
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.hexagon_outlined),
            selectedIcon: Icon(Icons.hexagon),
            label: 'This week',
          ),
          NavigationDestination(
            icon: Icon(Icons.event_outlined),
            selectedIcon: Icon(Icons.event),
            label: 'Weeks ahead',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: 'Journal',
          ),
          NavigationDestination(
            icon: Icon(Icons.groups_outlined),
            selectedIcon: Icon(Icons.groups),
            label: 'Family',
          ),
          NavigationDestination(
            icon: Icon(Icons.tune_outlined),
            selectedIcon: Icon(Icons.tune),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
