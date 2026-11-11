import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../src/data/repositories/audio_library_repository.dart';
import '../src/data/sources/platform/audio.dart';
import '../src/data/repositories/device_settings_repository.dart';
import '../src/data/repositories/family_repository.dart';
import '../src/data/repositories/journal_repository.dart';
import '../src/data/sources/notifications/reminders.dart';
import '../src/data/sources/platform/app_version.dart';
import '../src/data/sources/platform/identity.dart';
import '../src/data/sources/platform/photos.dart';
import '../src/data/sources/platform/sharing.dart';
import '../src/domain/ids.dart';
import 'presentation/brand/gallery.dart';
import 'presentation/brand/theme.dart';
import 'presentation/screens/home_shell.dart';
import 'presentation/screens/splash_gate.dart';

/// Which locales the app speaks, and in what order it falls back.
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
ThemeMode _themeModeFor(Appearance appearance) => switch (appearance) {
  Appearance.system => ThemeMode.system,
  Appearance.light => ThemeMode.light,
  Appearance.dark => ThemeMode.dark,
};

/// The application shell.
class MashibiniPrayerApp extends StatefulWidget {
  const MashibiniPrayerApp({
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
    this.initialAppearance = Appearance.system,
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

  /// The stored appearance, read before the first frame.
  final Appearance initialAppearance;

  static const String title = 'Mashibini Prayer';

  @override
  State<MashibiniPrayerApp> createState() => _MashibiniPrayerAppState();
}

class _MashibiniPrayerAppState extends State<MashibiniPrayerApp> {
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
                identity: widget.identity,
                audio: widget.audio,
                library: widget.library,
                photos: widget.photos,
                ids: widget.ids,
              ),
            ),
    );
  }
}
