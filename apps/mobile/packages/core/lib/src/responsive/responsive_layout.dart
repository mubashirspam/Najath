import 'package:flutter/widgets.dart';

import 'breakpoints.dart';

/// Picks a layout for the current width, falling back to the next smaller
/// variant when one is omitted — so a screen only builds the variants that
/// actually differ.
class ResponsiveLayout extends StatelessWidget {
  const ResponsiveLayout({
    required this.mobile,
    this.tablet,
    this.desktop,
    super.key,
  });

  final WidgetBuilder mobile;
  final WidgetBuilder? tablet;
  final WidgetBuilder? desktop;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        switch (screenTypeOfWidth(constraints.maxWidth)) {
          case ScreenType.desktop:
            return (desktop ?? tablet ?? mobile)(context);
          case ScreenType.tablet:
            return (tablet ?? mobile)(context);
          case ScreenType.mobile:
            return mobile(context);
        }
      },
    );
  }
}
