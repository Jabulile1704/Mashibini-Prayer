import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// The Mashibini Prayer mark: a ring of equal arcs, one of them filled.
///
/// The app answers one question — whose week is it — and the answer is always
/// "one of us, and then the next one". A ring divided into equal parts with
/// one part heavier is that idea and nothing else: a cycle, a current turn,
/// and the certainty that it comes round again.
///
/// Geometry rather than illustration, on purpose. It can be reasoned about,
/// regenerated at any size from one command, and it still reads at twenty
/// pixels, where anything with detail turns to mud.
class RotaMark extends StatelessWidget {
  const RotaMark({
    required this.size,
    required this.ringColour,
    required this.currentColour,
    this.parts = 4,
    this.current = 0,
    super.key,
  });

  final double size;
  final Color ringColour;

  /// The arc for whoever's week it is.
  final Color currentColour;

  /// How many people are in the ring. Four, because that is this family, and
  /// because four reads cleanly at icon sizes where six does not.
  final int parts;

  final int current;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: CustomPaint(
      painter: RotaMarkPainter(
        ringColour: ringColour,
        currentColour: currentColour,
        parts: parts,
        current: current,
      ),
    ),
  );
}

class RotaMarkPainter extends CustomPainter {
  const RotaMarkPainter({
    required this.ringColour,
    required this.currentColour,
    this.parts = 4,
    this.current = 0,
  });

  final Color ringColour;
  final Color currentColour;
  final int parts;
  final int current;

  /// The gap you actually see between arcs, as a fraction of each arc's
  /// share of the circle.
  ///
  /// Small enough that the ring still reads as a ring, large enough that the
  /// parts are countable at a glance.
  static const double _gapFraction = 0.17;

  @override
  void paint(Canvas canvas, Size size) {
    final double stroke = size.width * 0.13;
    final double radius = (size.width - stroke * 1.5) / 2;
    final Rect ring = Rect.fromCircle(
      center: Offset(size.width / 2, size.height / 2),
      radius: radius,
    );

    final double share = (math.pi * 2) / parts;
    final double gap = share * _gapFraction;

    for (int i = 0; i < parts; i++) {
      final bool isCurrent = i == current;
      final double width = isCurrent ? stroke * 1.45 : stroke;

      // A round cap extends half the stroke width past each end of the arc.
      // Subtracting it keeps every visible gap the same size — without this
      // the heavier current arc swells into its neighbours and the ring
      // looks approximate rather than drawn.
      final double capSpill = (width / 2) / radius;
      final double sweep = math.max(0.0, share - gap - capSpill * 2);

      // Each arc is centred in its own share, so thickening one does not
      // shift it off the quarter it belongs to.
      final double shareStart = -math.pi / 2 + share * i;
      final double begin = shareStart + (share - sweep) / 2;

      canvas.drawArc(
        ring,
        begin,
        sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = width
          ..color = isCurrent ? currentColour : ringColour,
      );
    }
  }

  @override
  bool shouldRepaint(RotaMarkPainter old) =>
      old.ringColour != ringColour ||
      old.currentColour != currentColour ||
      old.parts != parts ||
      old.current != current;
}
