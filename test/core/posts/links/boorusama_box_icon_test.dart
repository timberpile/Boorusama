import 'dart:ui' as ui;

import 'package:boorusama/core/posts/links/boorusama_box_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('link file icon renders three filled monochrome faces', (
    tester,
  ) async {
    const tint = Color(0xff234567);
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: RepaintBoundary(
            key: ValueKey('box-icon'),
            child: IconTheme(
              data: IconThemeData(color: tint, size: 48),
              child: BoorusamaBoxIcon(),
            ),
          ),
        ),
      ),
    );

    expect(tester.getSize(find.byType(BoorusamaBoxIcon)), const Size(48, 48));
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('box-icon')),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      try {
        final pixels = await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );
        expect(pixels, isNotNull);
        List<int> pixel(int x, int y) {
          final offset = (y * 48 + x) * 4;
          return [
            for (var i = 0; i < 4; i++) pixels!.getUint8(offset + i),
          ];
        }

        const filled = [0x23, 0x45, 0x67, 0xff];
        expect(pixel(24, 10), filled); // Top face.
        expect(pixel(12, 32), filled); // Left face.
        expect(pixel(36, 32), filled); // Right face.
        expect(pixel(24, 32)[3], 0); // Thin center seam.
      } finally {
        image.dispose();
      }
    });
  });

  testWidgets('explicit size and color override inherited icon theme', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: IconTheme(
          data: IconThemeData(color: Colors.red, size: 40),
          child: Center(
            child: BoorusamaBoxIcon(size: 20, color: Colors.blue),
          ),
        ),
      ),
    );

    expect(tester.getSize(find.byType(BoorusamaBoxIcon)), const Size(20, 20));
    expect(find.byType(CustomPaint), findsWidgets);
  });
}
