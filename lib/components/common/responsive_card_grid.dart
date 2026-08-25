import 'package:flutter/material.dart';

/// Lays cards out in as many columns as the width allows.
///
/// One column on phones, more on tablets and desktop. Uses a [Wrap] rather than
/// a fixed-aspect-ratio grid so a card that grows taller than expected pushes
/// its row down instead of overflowing.
class ResponsiveCardGrid extends StatelessWidget {
  final List<Widget> children;

  /// Narrowest a card may become before dropping a column.
  final double minTileWidth;
  final double spacing;
  final EdgeInsetsGeometry padding;

  const ResponsiveCardGrid({
    super.key,
    required this.children,
    this.minTileWidth = 340,
    this.spacing = 16,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final resolved = padding.resolve(Directionality.of(context));
        final available = constraints.maxWidth - resolved.horizontal;

        // How many tiles of at least minTileWidth fit, accounting for gutters.
        final columns = available <= 0
            ? 1
            : ((available + spacing) / (minTileWidth + spacing))
                .floor()
                .clamp(1, 4);

        final tileWidth = columns == 1
            ? available
            : (available - spacing * (columns - 1)) / columns;

        return SingleChildScrollView(
          // Always scrollable so pull-to-refresh works even when the content
          // is shorter than the viewport.
          physics: const AlwaysScrollableScrollPhysics(),
          padding: padding,
          child: Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: [
              for (final child in children)
                SizedBox(
                  width: tileWidth <= 0 ? null : tileWidth,
                  child: child,
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Centres content and caps its width so lists stay readable on wide screens.
class CenteredContent extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const CenteredContent({
    super.key,
    required this.child,
    this.maxWidth = 900,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
