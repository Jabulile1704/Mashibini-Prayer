import 'package:flutter/material.dart';

import '../brand/tokens.dart';

/// A message in the middle of an otherwise empty screen — that scrolls.
class CentredMessage extends StatelessWidget {
  const CentredMessage({
    required this.children,
    this.padding = const EdgeInsets.all(Space.xxl),
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
