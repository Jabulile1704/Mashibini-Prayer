import 'package:flutter/material.dart';

import '../../data/repositories/audio_library_repository.dart';
import '../../data/sources/platform/audio.dart';
import '../../data/repositories/device_settings_repository.dart';
import '../../data/repositories/family_repository.dart';
import '../../data/repositories/journal_repository.dart';
import '../../data/sources/notifications/reminders.dart';
import '../../data/sources/platform/app_version.dart';
import '../../data/sources/platform/identity.dart';
import '../../data/sources/platform/photos.dart';
import '../../data/sources/platform/sharing.dart';
import '../../domain/entities/calendar_date.dart';
import '../../domain/ids.dart';
import '../widgets/comb_bar.dart';
import 'songbook_screen.dart';
import 'journal_screen.dart';
import 'schedule_screen.dart';
import 'settings_screen.dart';
import 'this_week_screen.dart';

/// The five tabs, and the comb that moves between them (ADR-016, ADR-020,
/// ADR-022).
class HomeShell extends StatefulWidget {
  const HomeShell({
    required this.repository,
    required this.settings,
    required this.journal,
    required this.sharing,
    required this.reminders,
    required this.appVersion,
    required this.identity,
    required this.audio,
    required this.library,
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
  final Identity identity;
  final Audio audio;
  final AudioLibraryRepository library;
  final Photos photos;
  final IdGenerator ids;
  final CalendarDate Function()? today;

  static const Key bar = Key('shell.bar');

  /// Where the raised comb cell sits: the middle of five.
  static const int centre = 2;

  /// The five destinations, in the order they appear.
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
  int _tab = HomeShell.centre;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
          SongbookScreen(
            familyRepository: widget.repository,
            settings: widget.settings,
            audio: widget.audio,
            library: widget.library,
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
            identity: widget.identity,
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
