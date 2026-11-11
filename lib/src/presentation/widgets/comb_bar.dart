import 'package:flutter/material.dart';

import '../brand/mark.dart';
import '../brand/tokens.dart';

/// One destination in the [CombBar].
class CombDestination {
  const CombDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData selectedIcon;

  /// One word wherever one word will do.
  final String label;
}

/// The bottom bar: four destinations, and the one the app is about raised
/// into a comb cell between them.
class CombBar extends StatelessWidget {
  const CombBar({
    required this.destinations,
    required this.centreIndex,
    required this.selectedIndex,
    required this.onSelected,
    super.key,
  });

  /// Every destination, in the order they appear — including the centre.
  final List<CombDestination> destinations;

  /// Which of [destinations] is raised. Expected to be the middle one.
  final int centreIndex;

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  /// How far the comb cell rises above the bar.
  static const double overhang = Space.lg;

  /// The cell's width. Its height follows from the hexagon being regular.
  static const double cellWidth = 64;

  /// The flat part of the bar, below the overhang.
  static const double barHeight = 64;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double bottomInset = MediaQuery.paddingOf(context).bottom;

    return SizedBox(
      height: barHeight + overhang + bottomInset,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              height: barHeight + bottomInset,
              padding: EdgeInsets.only(bottom: bottomInset),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainer,
                border: Border(
                  top: BorderSide(color: theme.colorScheme.outlineVariant),
                ),
              ),
              child: Row(
                children: <Widget>[
                  for (int i = 0; i < destinations.length; i++)
                    if (i == centreIndex)
                      const SizedBox(width: cellWidth + Space.sm)
                    else
                      Expanded(
                        child: _SideDestination(
                          destination: destinations[i],
                          selected: i == selectedIndex,
                          onTap: () => onSelected(i),
                        ),
                      ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Center(
              child: _CentreCell(
                destination: destinations[centreIndex],
                selected: centreIndex == selectedIndex,
                onTap: () => onSelected(centreIndex),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One of the four ordinary destinations.
class _SideDestination extends StatelessWidget {
  const _SideDestination({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final CombDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color colour = selected
        ? theme.colorScheme.secondary
        : theme.colorScheme.onSurfaceVariant;

    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      onTap: onTap,
      child: ExcludeSemantics(
        child: InkResponse(
          onTap: onTap,
          radius: Touch.minimum,
          child: SizedBox(
            height: Touch.minimum,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(
                  selected ? destination.selectedIcon : destination.icon,
                  size: 22,
                  color: colour,
                ),
                const SizedBox(height: Space.xs),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    destination.label,
                    maxLines: 1,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colour,
                      fontWeight: selected ? FontWeight.w600 : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The raised comb cell in the middle.
class _CentreCell extends StatelessWidget {
  const _CentreCell({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final CombDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    // A regular flat-topped hexagon is shorter than it is wide.
    const double height = CombBar.cellWidth * 0.9;

    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      onTap: onTap,
      child: ExcludeSemantics(
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: SizedBox(
            width: CombBar.cellWidth + Space.sm,
            height: Touch.minimum > height ? Touch.minimum : height,
            child: Center(
              child: ClipPath(
                clipper: _CellClipper(),
                child: Container(
                  width: CombBar.cellWidth,
                  height: height,
                  color: selected
                      ? theme.colorScheme.secondary
                      : theme.colorScheme.surfaceContainerHighest,
                  alignment: Alignment.center,
                  child: RotaMark(
                    size: CombBar.cellWidth * 0.46,
                    parts: 4,
                    current: 0,
                    ringColour: selected
                        ? theme.colorScheme.onSecondary.withValues(alpha: 0.55)
                        : theme.colorScheme.onSurfaceVariant,
                    currentColour: selected
                        ? theme.colorScheme.onSecondary
                        : theme.colorScheme.secondary,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The app's own hexagon, as a clip.
class _CellClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) => CombMarkPainter.cell(
    Offset(size.width / 2, size.height / 2),
    size.width / 2,
  );

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
