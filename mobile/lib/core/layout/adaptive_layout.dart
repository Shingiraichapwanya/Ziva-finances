import 'package:flutter/material.dart';

/// Breakpoints and utility methods for responsive layout switching
/// between the Lean Mobile Capture App and the Desktop Command Center.
class AdaptiveLayout {
  /// Standard Material 3 breakpoint separating hand-held mobile devices
  /// from desktop / widescreen displays.
  static const double desktopBreakpoint = 840.0;

  /// Check if current viewport should render Desktop Command Center
  static bool isDesktop(BuildContext context) {
    return MediaQuery.sizeOf(context).width >= desktopBreakpoint;
  }

  /// Check if current viewport should render Mobile Lean Capture View
  static bool isMobile(BuildContext context) {
    return MediaQuery.sizeOf(context).width < desktopBreakpoint;
  }
}
