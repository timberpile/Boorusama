import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  late Directory outputRoot;
  late ProcessResult generationResult;
  late ProcessResult platformGenerationResult;

  setUpAll(() async {
    outputRoot = await Directory.systemTemp.createTemp('boorusama_icons_');
    final source = File('${outputRoot.path}/assets/images/logo.png');
    await source.parent.create(recursive: true);
    await File('assets/images/logo.png').copy(source.path);
    await File('assets/images/logo-dev.png').copy(
      '${outputRoot.path}/assets/images/logo-dev.png',
    );
    await _copyFixture(
      outputRoot,
      'macos/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json',
    );
    await _copyFixture(outputRoot, 'web/manifest.json');

    generationResult = await Process.run('fvm', [
      'dart',
      'run',
      'tool/generate_app_icon_sources.dart',
      '--root',
      outputRoot.path,
    ]);
    platformGenerationResult = await Process.run('fvm', [
      'dart',
      'run',
      'tool/generate_app_icon_flavor_outputs.dart',
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

  test('creates platform inputs for the dev flavor', () {
    expect(
      generationResult.exitCode,
      0,
      reason: '${generationResult.stdout}\n${generationResult.stderr}',
    );

    for (final path in _sourceIconPaths) {
      final icon = _decode('${outputRoot.path}/assets/icon/dev/$path');
      expect(icon.width, greaterThan(0), reason: path);
      expect(icon.height, greaterThan(0), reason: path);
    }
  });

  test('creates production and development desktop and web icons', () {
    expect(
      platformGenerationResult.exitCode,
      0,
      reason:
          '${platformGenerationResult.stdout}\n'
          '${platformGenerationResult.stderr}',
    );

    for (final path in _platformOutputPaths) {
      expect(
        File('${outputRoot.path}/$path').existsSync(),
        isTrue,
        reason: path,
      );
    }

    final manifest = File(
      '${outputRoot.path}/web/manifest-dev.json',
    ).readAsStringSync();
    expect(manifest, contains('icons-dev/Icon-192.png'));
    expect(manifest, isNot(contains('"src": "icons/Icon-192.png"')));
  });
}

Future<void> _copyFixture(Directory outputRoot, String path) async {
  final destination = File('${outputRoot.path}/$path');
  await destination.parent.create(recursive: true);
  await File(path).copy(destination.path);
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

const _sourceIconPaths = [
  'icon-512x512.png',
  'icon-ios.png',
  'icon-macos.png',
  'icon-monochrome-512x512.png',
  'icon-windows.png',
];

const _platformOutputPaths = [
  'macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_16.png',
  'macos/Runner/Assets.xcassets/AppIconDev.appiconset/app_icon_16.png',
  'windows/runner/resources/app_icon.ico',
  'windows/runner/resources/app_icon_dev.ico',
  'web/favicon.png',
  'web/favicon-dev.png',
  'web/icons/Icon-192.png',
  'web/icons-dev/Icon-192.png',
  'web/manifest-dev.json',
];
