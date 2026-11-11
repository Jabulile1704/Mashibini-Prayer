import 'package:flutter/material.dart';

import '../../data/repositories/family_repository.dart';
import '../brand/mark.dart';
import '../brand/palette.dart';
import '../brand/tokens.dart';

/// Holds the mark until the app has something to show, then resolves into it.
class SplashGate extends StatefulWidget {
  const SplashGate({required this.repository, required this.child, super.key});

  final FamilyRepository repository;

  /// What to show once there is something to show.
  final Widget child;

  /// Long enough not to flash, short enough that nobody is waiting on it.
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
          child: ready ? widget.child : const _Holding(),
        );
      },
    );
  }
}

/// The launch image, redrawn in Flutter so it can fade.
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
