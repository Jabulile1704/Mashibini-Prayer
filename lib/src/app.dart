import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../src/data/repositories/device_settings_repository.dart';
import '../src/data/repositories/family_repository.dart';
import '../src/data/repositories/journal_repository.dart';
import '../src/data/sources/notifications/reminders.dart';
import '../src/data/sources/platform/app_version.dart';
import '../src/data/sources/platform/photos.dart';
import '../src/data/sources/platform/sharing.dart';
import '../src/domain/ids.dart';
import 'presentation/brand/gallery.dart';
import 'presentation/brand/theme.dart';
import 'presentation/screens/home_shell.dart';
import 'presentation/screens/splash_gate.dart';

/// Which locales the app speaks, and in what order it falls back.
///
/// This matters for one small, visible reason: date order. Flutter's default
/// `MaterialLocalizations` formats a full date American-style — "Sunday,
/// October 25, 2026" — and this app is read by a family in South Africa, who
/// write "Sunday 25 October 2026".
///
/// Flutter ships `MaterialLocalizationEnZa`, so this is a matter of asking
/// for it. `en_ZA` is listed first because Flutter falls back to the first
/// supported locale when the device's own is not matched: a phone set to a
/// locale we do not list gets South African formatting rather than American.
abstract final class AppLocales {
  static const List<Locale> supported = <Locale>[
    Locale('en', 'ZA'),
    Locale('en', 'GB'),
    Locale('en'),
  ];

  static const List<LocalizationsDelegate<Object?>> delegates =
      <LocalizationsDelegate<Object?>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ];
}

/// Flutter's name for each of the three choices.
///
/// The only place the stored [Appearance] meets a Flutter type. Keeping the
/// map here rather than on the enum is what lets `data/` stay free of
/// Flutter imports (ARCHITECTURE.md).
ThemeMode _themeModeFor(Appearance appearance) => switch (appearance) {
  Appearance.system => ThemeMode.system,
  Appearance.light => ThemeMode.light,
  Appearance.dark => ThemeMode.dark,
};

/// The application shell.
///
/// Takes its repository rather than building one, so a test can hand it a
/// fake and the whole app runs without a device, a plugin or a disk.
class MashibiniPrayerApp extends StatefulWidget {
  const MashibiniPrayerApp({
    required this.repository,
    required this.settings,
    required this.journal,
    required this.sharing,
    required this.reminders,
    required this.appVersion,
    required this.photos,
    required this.ids,
    this.initialAppearance = Appearance.system,
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

  /// The stored appearance, read before the first frame.
  ///
  /// `watchAppearance()` yields its first value asynchronously, so a stream
  /// alone would paint one frame of the wrong theme — and because the splash
  /// is the first thing on screen, a phone set to light with the app set to
  /// dark would flash white and then go dark on every cold start. `main()`
  /// reads it before `runApp`, which costs one await and removes the flash
  /// entirely. Tests that do not care may leave it.
  final Appearance initialAppearance;

  static const String title = 'Mashibini Prayer';

  @override
  State<MashibiniPrayerApp> createState() => _MashibiniPrayerAppState();
}

class _MashibiniPrayerAppState extends State<MashibiniPrayerApp> {
  // Subscribed once. A stream expression inside build() would hand the
  // builder a fresh subscription on every frame.
  late final Stream<Appearance> _appearance = widget.settings.watchAppearance();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Appearance>(
      stream: _appearance,
      initialData: widget.initialAppearance,
      builder: (BuildContext context, AsyncSnapshot<Appearance> chosen) =>
          _app(chosen.data ?? Appearance.system),
    );
  }

  Widget _app(Appearance appearance) {
    return MaterialApp(
      title: MashibiniPrayerApp.title,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: AppLocales.delegates,
      supportedLocales: AppLocales.supported,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: _themeModeFor(appearance),
      // Reviewing the design system should not mean editing this file and
      // remembering to put it back. `--dart-define=GALLERY=true` costs
      // nothing in a normal build.
      home: BrandGallery.requested
          ? const BrandGallery()
          : SplashGate(
              repository: widget.repository,
              child: HomeShell(
                repository: widget.repository,
                settings: widget.settings,
                journal: widget.journal,
                sharing: widget.sharing,
                reminders: widget.reminders,
                appVersion: widget.appVersion,
                photos: widget.photos,
                ids: widget.ids,
              ),
            ),
    );
  }
}
