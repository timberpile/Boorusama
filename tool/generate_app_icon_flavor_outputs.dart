import 'dart:convert';
import 'dart:io';

import 'package:image/image.dart' as img;

void main(List<String> arguments) {
  final root = _rootFrom(arguments);
  final production = _readSources(root, 'assets/icon');
  final development = _readSources(root, 'assets/icon/dev');

  _writeMacosIcons(root, production.macos, development.macos);
  _writeWindowsIcons(root, production.windows, development.windows);
  _writeWebIcons(root, production.compact, development.compact);
}

String _rootFrom(List<String> arguments) {
  if (arguments.isEmpty) return Directory.current.path;
  if (arguments.length == 2 && arguments.first == '--root') {
    return Directory(arguments.last).absolute.path;
  }
  throw ArgumentError(
    'Usage: generate_app_icon_flavor_outputs.dart [--root <path>]',
  );
}

({img.Image compact, img.Image macos, img.Image windows}) _readSources(
  String root,
  String directory,
) => (
  compact: _decode('$root/$directory/icon-512x512.png'),
  macos: _decode('$root/$directory/icon-macos.png'),
  windows: _decode('$root/$directory/icon-windows.png'),
);

img.Image _decode(String path) {
  final image = img.decodeImage(File(path).readAsBytesSync());
  if (image == null) throw StateError('Could not decode $path');
  return image;
}

void _writeMacosIcons(
  String root,
  img.Image production,
  img.Image development,
) {
  const productionPath = 'macos/Runner/Assets.xcassets/AppIcon.appiconset';
  const developmentPath = 'macos/Runner/Assets.xcassets/AppIconDev.appiconset';
  final contents = File(
    '$root/$productionPath/Contents.json',
  ).readAsStringSync();
  final catalog = jsonDecode(contents) as Map<String, dynamic>;

  for (final entry in catalog['images'] as List<dynamic>) {
    final specification = entry as Map<String, dynamic>;
    final filename = specification['filename'] as String?;
    if (filename == null) continue;
    final size = double.parse(
      (specification['size'] as String).split('x').first,
    );
    final scale = double.parse(
      (specification['scale'] as String).replaceAll('x', ''),
    );
    final pixels = (size * scale).round();
    _writePng(root, '$productionPath/$filename', _resize(production, pixels));
    _writePng(
      root,
      '$developmentPath/$filename',
      _resize(development, pixels),
    );
  }

  _writeBytes(root, '$developmentPath/Contents.json', utf8.encode(contents));
}

void _writeWindowsIcons(
  String root,
  img.Image production,
  img.Image development,
) {
  _writeBytes(
    root,
    'windows/runner/resources/app_icon.ico',
    img.encodeIco(_resize(production, 256)),
  );
  _writeBytes(
    root,
    'windows/runner/resources/app_icon_dev.ico',
    img.encodeIco(_resize(development, 256)),
  );
}

void _writeWebIcons(
  String root,
  img.Image production,
  img.Image development,
) {
  _writeWebFlavor(root, production, development: false);
  _writeWebFlavor(root, development, development: true);

  final manifest =
      jsonDecode(File('$root/web/manifest.json').readAsStringSync())
          as Map<String, dynamic>;
  for (final entry in manifest['icons'] as List<dynamic>) {
    final icon = entry as Map<String, dynamic>;
    icon['src'] = (icon['src'] as String).replaceFirst(
      'icons/',
      'icons-dev/',
    );
  }
  _writeBytes(
    root,
    'web/manifest-dev.json',
    utf8.encode('${const JsonEncoder.withIndent('    ').convert(manifest)}\n'),
  );
}

void _writeWebFlavor(
  String root,
  img.Image source, {
  required bool development,
}) {
  final suffix = development ? '-dev' : '';
  final directory = development ? 'icons-dev' : 'icons';
  final maskable = _withGoldBackground(source);

  _writePng(root, 'web/favicon$suffix.png', _resize(source, 16));
  for (final size in [192, 512]) {
    _writePng(root, 'web/$directory/Icon-$size.png', _resize(source, size));
    _writePng(
      root,
      'web/$directory/Icon-maskable-$size.png',
      _resize(maskable, size),
    );
  }
}

img.Image _withGoldBackground(img.Image source) {
  final background = img.Image(width: source.width, height: source.height);
  img.fill(background, color: img.ColorRgb8(231, 191, 85));
  return img.compositeImage(background, source);
}

img.Image _resize(img.Image source, int size) => img.copyResize(
  source,
  width: size,
  height: size,
  interpolation: img.Interpolation.linear,
);

void _writePng(String root, String path, img.Image image) {
  _writeBytes(root, path, img.encodePng(image));
}

void _writeBytes(String root, String path, List<int> bytes) {
  final file = File('$root/$path');
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(bytes);
}
