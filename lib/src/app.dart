import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../src/data/repositories/device_settings_repository.dart';
import '../src/data/repositories/family_repository.dart';
import '../src/domain/ids.dart';
import 'presentation/screens/this_week_screen.dart';

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

/// The application shell.
///
/// Takes its repository rather than building one, so a test can hand it a
/// fake and the whole app runs without a device, a plugin or a disk.
class MashibiniPrayerApp extends StatelessWidget {
  const MashibiniPrayerApp({
    required this.repository,
    required this.settings,
    required this.ids,
    super.key,
  });

  final FamilyRepository repository;
  final DeviceSettingsRepository settings;
  final IdGenerator ids;

  static const String title = 'Mashibini Prayer';

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: title,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: AppLocales.delegates,
      supportedLocales: AppLocales.supported,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3F5E8C)),
      ),
      home: ThisWeekScreen(
        repository: repository,
        settings: settings,
        ids: ids,
      ),
    );
  }
}
