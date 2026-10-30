import 'package:flutter/material.dart';

/// A message in the middle of an otherwise empty screen — that scrolls.
///
/// Every empty state in this app is a short column centred in the viewport,
/// and every one of them overflows at the largest accessibility text size:
/// two sentences at 3.1x are taller than a phone, and a centred `Column` has
/// nowhere to put the overflow but off the bottom of the screen (N5).
///
/// Found on a simulator at AX5, on the one empty state the test sweep had
/// not rendered — the sweep seeded data before pumping, so it only ever saw
/// the populated screens. This type exists so the next empty state inherits
/// the fix instead of rediscovering the bug.
class CentredMessage extends StatelessWidget {
  const CentredMessage({
    required this.children,
    this.padding = const EdgeInsets.all(40),
    super.key,
  });

  final List<Widget> children;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) =>
          SingleChildScrollView(
            padding: padding,
            child: ConstrainedBox(
              // Centred while it fits, scrolled once it does not.
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - padding.vertical,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: children,
              ),
            ),
          ),
    );
  }
}
