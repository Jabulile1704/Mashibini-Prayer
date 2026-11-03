import 'package:flutter/material.dart';

import '../../data/repositories/family_repository.dart';
import '../brand/mark.dart';
import '../brand/palette.dart';
import '../brand/tokens.dart';

/// Holds the mark until the app has something to show, then resolves into it.
///
/// Before this there was a seam. The platform drew its launch image — the
/// mark on ink — then handed over to Flutter, which showed a spinner while
/// the first read of storage completed, then the rota appeared. Three
/// states in under a second, two of which say nothing.
///
/// This is one state. The ground and the mark match the native launch image
/// exactly, so the handover is invisible, and the app fades up underneath
/// when it is genuinely ready.
///
/// It waits for **the later of** the first read and [_minimum]. Waiting for
/// the read alone makes a fast phone flash; waiting a fixed time alone makes
/// a slow one lie about being ready.
class SplashGate extends StatefulWidget {
  const SplashGate({required this.repository, required this.child, super.key});

  final FamilyRepository repository;

  /// What to show once there is something to show.
  final Widget child;

  /// Long enough not to flash, short enough that nobody is waiting on it.
  ///
  /// A splash exists to cover work. One that outlasts the work is an
  /// animation somebody sits through every single morning.
  static const Duration _minimum = Duration(milliseconds: 650);

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> {
  late final Future<void> _ready = _wait();

  Future<void> _wait() async {
    await Future.wait(<Future<Object?>>[
      widget.repository.load(),
      Future<void>.delayed(SplashGate._minimum),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _ready,
      builder: (BuildContext context, AsyncSnapshot<void> snapshot) {
        final bool ready = snapshot.connectionState == ConnectionState.done;

        return AnimatedSwitcher(
          duration: Motion.settle,
          // Crossfade rather than a slide or a scale. The mark is already
          // on screen from the native launch image; anything that moves it
          // draws attention to a handover that should be invisible.
          child: ready ? widget.child : const _Holding(),
        );
      },
    );
  }
}

/// The launch image, redrawn in Flutter so it can fade.
///
/// The colours are [Palette.ink] and [Palette.honey] because the native
/// launch screens use exactly those — `LaunchScreen.storyboard` and
/// `launch_background.xml`, both kept in step by hand (BRAND.md). If this
/// drifts from them, the seam comes back as a flash of the wrong colour.
class _Holding extends StatelessWidget {
  const _Holding();

  @override
  Widget build(BuildContext context) => const ColoredBox(
    color: Palette.ink,
    child: Center(
      child: RotaMark(
        size: 112,
        parts: 4,
        current: 0,
        ringColour: Color(0x6BFFF9ED),
        currentColour: Palette.honey,
      ),
    ),
  );
}
