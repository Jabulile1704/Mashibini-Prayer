import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// The Mashibini Prayer mark: a cluster of comb cells, one of them filled.
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
