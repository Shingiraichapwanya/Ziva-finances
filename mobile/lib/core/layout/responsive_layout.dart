import 'package:flutter/material.dart';

/// ResponsiveLayout determines the presentation tree dynamically
/// using a LayoutBuilder on the incoming BoxConstraints.
class ResponsiveLayout extends StatelessWidget {
  /// Mobile single-column layout for small viewports (< breakpoint)
  final Widget mobile;

  /// Desktop multi-column Command Center layout for widescreen viewports (>= breakpoint)
  final Widget desktop;

  /// Breakpoint width driving the layout switch. Defaults to 800.0px.
  final double breakpoint;

  const ResponsiveLayout({
    super.key,
    required this.mobile,
    required this.desktop,
    this.breakpoint = 800.0,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= breakpoint) {
          return desktop;
        }
        return mobile;
      },
    );
  }
}
