import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// The Mashibini Prayer mark: a cluster of comb cells, one of them filled.
///
/// The family's totem is the bee, and a comb cell is the one bee shape that
/// is not a cartoon — no face, no wings, no antennae, none of which survive
/// at icon size. A hexagon does.
///
/// It is also the only mark considered that **does work**. One cell per
/// person, the filled one is whose week it is, so the logo is the app's
/// actual state rather than a picture beside it. A family of four reads as
/// four cells; a family of six reads as six.
///
/// Supersedes the ring of arcs from Day 8 (ADR-017). The idea is unchanged —
/// equal parts, one of them current, a cycle that comes round — and only the
/// geometry is different.
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

  /// The outline of a cell that is not this week's.
  final Color ringColour;

  /// The fill for whoever's week it is.
  final Color currentColour;

  /// How many people are in the rota.
  final int parts;

  /// Which one leads this week, or a negative number for none — the empty
  /// comb of a family that has not set up a rota yet.
  final int current;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: CustomPaint(
      painter: CombMarkPainter(
        ringColour: ringColour,
        currentColour: currentColour,
        parts: parts,
        current: current,
      ),
    ),
  );
}

/// Draws the comb.
///
/// Cells are laid out on a ring rather than in a honeycomb lattice. A true
/// lattice packs tightly and is lovely at poster size; at 20 pixels it turns
/// to mud, and the one thing this mark has to survive is being small.
class CombMarkPainter extends CustomPainter {
  const CombMarkPainter({
    required this.ringColour,
    required this.currentColour,
    this.parts = 4,
    this.current = 0,
  });

  final Color ringColour;
  final Color currentColour;
  final int parts;
  final int current;

  /// A flat-topped hexagon's path, centred on [centre].
  ///
  /// Flat-topped rather than pointy-topped because a row of flat-tops sits
  /// level with the type beside it; pointy-tops look like they are falling
  /// over.
  static Path cell(Offset centre, double radius) {
    final Path path = Path();
    for (int corner = 0; corner < 6; corner++) {
      final double angle = math.pi / 180 * (60 * corner);
      final Offset point = Offset(
        centre.dx + radius * math.cos(angle),
        centre.dy + radius * math.sin(angle),
      );
      if (corner == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    return path..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final Offset centre = Offset(size.width / 2, size.height / 2);

    // One cell: draw it in the middle rather than orbiting nothing.
    if (parts <= 1) {
      _draw(canvas, centre, size.width * 0.42, current == 0);
      return;
    }

    // Solved rather than guessed, because guessing was wrong.
    //
    // Adjacent centres on the ring are `2 · orbit · sin(π/n)` apart, and two
    // cells clear each other when that is at least `2 · radius`. With
    // `orbit + radius` fixed at half the width, the largest radius that
    // still clears is:
    //
    //   radius = (size / 2) / (1 + 1 / sin(π / n))
    //
    // The first version used a flat 0.24 of the width with a comment saying
    // the cells did not touch. At four cells they overlapped by a third —
    // visible the moment the mark was drawn at 112px on a splash screen and
    // invisible in every test, because nothing measures whether a picture
    // is a tangle.
    final double share = math.sin(math.pi / parts);
    // The 0.94 is the visible gap. Touching exactly is still unreadable.
    final double cellRadius = (size.width / 2) / (1 + 1 / share) * 0.94;
    final double orbit = size.width / 2 - cellRadius;

    for (int i = 0; i < parts; i++) {
      // Starting at the top, so the first person sits where a reader looks.
      final double angle = -math.pi / 2 + (math.pi * 2 / parts) * i;
      final Offset at = Offset(
        centre.dx + orbit * math.cos(angle),
        centre.dy + orbit * math.sin(angle),
      );
      _draw(canvas, at, cellRadius, i == current);
    }
  }

  void _draw(Canvas canvas, Offset at, double radius, bool isCurrent) {
    final Path path = cell(at, radius);

    if (isCurrent) {
      canvas.drawPath(path, Paint()..color = currentColour);
      return;
    }

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.22
        ..strokeJoin = StrokeJoin.round
        ..color = ringColour,
    );
  }

  @override
  bool shouldRepaint(CombMarkPainter old) =>
      old.ringColour != ringColour ||
      old.currentColour != currentColour ||
      old.parts != parts ||
      old.current != current;
}
