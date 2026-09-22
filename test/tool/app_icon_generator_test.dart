import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  late Directory outputRoot;
  late ProcessResult generationResult;

  setUpAll(() async {
    outputRoot = await Directory.systemTemp.createTemp('boorusama_icons_');
    final source = File('${outputRoot.path}/assets/images/logo.png');
    await source.parent.create(recursive: true);
    await File('assets/images/logo.png').copy(source.path);

    generationResult = await Process.run('fvm', [
      'dart',
      'run',
      'tool/generate_app_icon_sources.dart',
      '--root',
      outputRoot.path,
    ]);
  });

  tearDownAll(() async {
    await outputRoot.delete(recursive: true);
  });

  for (final iconCase in _monochromeImageCases) {
    test('${iconCase.path} is a transparent black silhouette', () {
      expect(
        generationResult.exitCode,
        0,
        reason: '${generationResult.stdout}\n${generationResult.stderr}',
      );

      final actual = _decode('${outputRoot.path}/${iconCase.path}');
      expect(actual.width, iconCase.size, reason: iconCase.path);
      expect(actual.height, iconCase.size, reason: iconCase.path);

      var hasTransparentPixel = false;
      var hasVisiblePixel = false;
      var hasColoredPixel = false;
      for (final pixel in actual) {
        hasTransparentPixel |= pixel.a == 0;
        hasVisiblePixel |= pixel.a > 0;
        hasColoredPixel |=
            pixel.a > 0 && (pixel.r != 0 || pixel.g != 0 || pixel.b != 0);
      }
      expect(hasTransparentPixel, isTrue, reason: iconCase.path);
      expect(hasVisiblePixel, isTrue, reason: iconCase.path);
      expect(hasColoredPixel, isFalse, reason: iconCase.path);
    });
  }

  test('leaves platform launcher assets to flutter_launcher_icons', () {
    expect(
      generationResult.exitCode,
      0,
      reason: '${generationResult.stdout}\n${generationResult.stderr}',
    );
    expect(
      File(
        '${outputRoot.path}/android/app/src/main/res/mipmap-mdpi/ic_launcher.png',
      ).existsSync(),
      isFalse,
    );
  });
}

img.Image _decode(String path) {
  final image = img.decodeImage(File(path).readAsBytesSync());
  if (image == null) {
    throw StateError('Could not decode $path');
  }
  return image;
}

const _monochromeImageCases = [
  (path: 'assets/icon/icon-monochrome-512x512.png', size: 512),
];
