import 'package:boorusama/core/themes/system_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/material.dart';

void main() {
  for (final dark in [false, true]) {
    for (final gesture in [false, true]) {
      test(
        'system bars honor actual surface brightness and navigation mode $dark/$gesture',
        () {
          final colors = ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: dark ? Brightness.dark : Brightness.light,
          );
          final style = appSystemUiOverlayStyle(
            colors: colors,
            gestureNavigation: gesture,
          );
          expect(style.statusBarColor, Colors.transparent);
          expect(
            style.systemNavigationBarColor,
            gesture ? Colors.transparent : colors.surface,
          );
          expect(
            style.statusBarIconBrightness,
            dark ? Brightness.light : Brightness.dark,
          );
          expect(
            style.systemNavigationBarIconBrightness,
            style.statusBarIconBrightness,
          );
          expect(style.systemNavigationBarContrastEnforced, isFalse);
        },
      );
    }
  }
}
