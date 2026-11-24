import 'dart:io';
import 'dart:ui' as ui;

import 'package:boorusama/core/backups/mitemite/mitemite_icon.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/material.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('approved vector bytes remain unchanged', () async {
    final bytes = await rootBundle.load('assets/icon/mitemite.svg');
    expect(
      sha256.convert(bytes.buffer.asUint8List()).toString(),
      '154cdfaad6869d3133ecb94818f6d1e05f9aaf3a3b8888b74f1b0ab0519c852e',
    );
  });

  for (final brightness in Brightness.values) {
    for (final size in [16.0, 20.0, 24.0, 32.0]) {
      testWidgets('approved icon rasterizes at $size in $brightness', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(320, 720);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        final dark = brightness == Brightness.dark;
        final foreground = dark ? Colors.white : Colors.black;
        final background = dark ? Colors.black : Colors.white;
        const capture = ValueKey('icon-capture');
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(brightness: brightness),
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(320, 720),
                textScaler: TextScaler.linear(2),
              ),
              child: IconTheme(
                data: IconThemeData(color: foreground),
                child: Center(
                  child: RepaintBoundary(
                    key: capture,
                    child: ColoredBox(
                      color: background,
                      child: MiteMiteIcon(size: size),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.runAsync(() async {});
        await tester.pumpAndSettle();
        expect(tester.getSize(find.byKey(capture)), Size.square(size));
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(capture),
        );
        await tester.runAsync(() async {
          final image = await boundary.toImage();
          try {
            final raw = (await image.toByteData())!.buffer.asUint8List();
            var contrasting = 0;
            for (var offset = 0; offset < raw.length; offset += 4) {
              if (dark ? raw[offset] > 128 : raw[offset] < 128) contrasting++;
            }
            expect(
              contrasting,
              greaterThan(8),
              reason:
                  'The tinted vector must actually paint against its surface',
            );
            final output =
                Platform.environment['MITEMITE_ICON_EVIDENCE_DIRECTORY'];
            if (output != null) {
              await Directory(output).create(recursive: true);
              final png = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              final name = '$output/${brightness.name}-${size.toInt()}.png';
              await File(name).writeAsBytes(png!.buffer.asUint8List());
            }
          } finally {
            image.dispose();
          }
        });
        expect(tester.takeException(), isNull);
      });
    }
  }
}
