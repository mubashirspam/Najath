import 'package:flutter/widgets.dart';

/// Layout classes the app renders for.
enum ScreenType { mobile, tablet, desktop }

const double kTabletBreakpoint = 768;
const double kDesktopBreakpoint = 1200;

ScreenType screenTypeOfWidth(double width) {
  if (width >= kDesktopBreakpoint) return ScreenType.desktop;
  if (width >= kTabletBreakpoint) return ScreenType.tablet;
  return ScreenType.mobile;
}

ScreenType screenTypeOf(BuildContext context) =>
    screenTypeOfWidth(MediaQuery.sizeOf(context).width);
