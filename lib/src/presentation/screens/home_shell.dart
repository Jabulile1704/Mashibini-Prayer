import 'package:flutter/material.dart';

import '../../data/repositories/device_settings_repository.dart';
import '../../data/repositories/family_repository.dart';
import '../../data/repositories/journal_repository.dart';
import '../../data/sources/notifications/reminders.dart';
import '../../data/sources/platform/app_version.dart';
import '../../domain/entities/calendar_date.dart';
import '../../domain/ids.dart';
import 'journal_screen.dart';
import 'schedule_screen.dart';
import 'settings_screen.dart';
import 'this_week_screen.dart';

/// The four tabs, and the bar that moves between them (ADR-016).
///
/// Before this, every destination in the app was a `Navigator.push` from
/// This Week, three of them from icon buttons in the top-right — the hardest
/// place on a phone to reach one-handed and the easiest to miss. Day 13's
/// accessibility pass gave those icons screen-reader names; a name does not
/// make an unlabelled icon discoverable to somebody looking at the screen.
///
/// Four is the ceiling ADR-016 set. A fifth destination means rethinking,
/// not adding.
class HomeShell extends StatefulWidget {
  const HomeShell({
    required this.repository,
    required this.settings,
    required this.journal,
    required this.reminders,
    required this.appVersion,
    required this.ids,
    this.today,
    super.key,
  });

  final FamilyRepository repository;
  final DeviceSettingsRepository settings;
  final JournalRepository journal;
  final Reminders reminders;
  final AppVersion appVersion;
  final IdGenerator ids;
  final CalendarDate Function()? today;

  static const Key bar = Key('shell.bar');

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
          SettingsScreen(
            familyRepository: widget.repository,
            settings: widget.settings,
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
            icon: Icon(Icons.tune_outlined),
            selectedIcon: Icon(Icons.tune),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
