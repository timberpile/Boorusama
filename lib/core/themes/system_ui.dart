import 'package:flutter/services.dart';
import 'package:kurumi/material.dart';

/// Timeline viewports paint the status inset; gesture navigation stays edge-to-edge.
SystemUiOverlayStyle appSystemUiOverlayStyle({
  required ColorScheme colors,
  required bool gestureNavigation,
}) {
  final icons = colors.brightness == Brightness.dark
      ? Brightness.light
      : Brightness.dark;
  return SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarBrightness: colors.brightness,
    statusBarIconBrightness: icons,
    systemNavigationBarColor: gestureNavigation
        ? Colors.transparent
        : colors.surface,
    systemNavigationBarIconBrightness: icons,
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarContrastEnforced: false,
  );
}
