import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets(
      'search field retains its default surface over a painted parent: $brightness',
      (tester) async {
        final theme = ThemeData(brightness: brightness);
        const backing = Color(0xFF527A38);
        final key = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            builder: (context, child) => KurumiTheme(
              data: KurumiThemeData.fromMaterial(Theme.of(context)),
              child: child!,
            ),
            home: Scaffold(
              body: Center(
                child: RepaintBoundary(
                  key: key,
                  child: ColoredBox(
                    color: backing,
                    child: SizedBox(
                      width: 300,
                      height: 48,
                      child: const KurumiSearchBar(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await tester.runAsync(() => boundary.toImage());
        final bytes = await tester.runAsync(
          () => image!.toByteData(format: ui.ImageByteFormat.rawRgba),
        );
        final offset = (24 * image!.width + 4) * 4;
        final actual = Color.fromARGB(
          bytes!.getUint8(offset + 3),
          bytes.getUint8(offset),
          bytes.getUint8(offset + 1),
          bytes.getUint8(offset + 2),
        );
        expect(
          actual,
          brightness == Brightness.dark
              ? theme.colorScheme.surfaceContainerHigh
              : theme.colorScheme.surfaceContainerHighest,
        );
        image.dispose();
        expect(tester.takeException(), isNull);
      },
    );
  }
}
