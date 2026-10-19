import 'package:flutter/material.dart';

/// The application shell.
///
/// Day 1: the scaffold only. The rota engine lands on Day 3 and this
/// placeholder is replaced by the real home screen on Day 5 — see
/// `docs/SDLC.md` for the plan.
class MashibiniPrayerApp extends StatelessWidget {
  const MashibiniPrayerApp({super.key});

  static const String title = 'Mashibini Prayer';

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: title,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3F5E8C)),
      ),
      home: const _UnderConstruction(),
    );
  }
}

class _UnderConstruction extends StatelessWidget {
  const _UnderConstruction();

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  MashibiniPrayerApp.title,
                  style: text.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Whose week it is to lead family prayer.',
                  style: text.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Text(
                  'In build — the rota arrives on day 5.',
                  style: text.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
