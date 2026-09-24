import 'dart:io';

import 'package:image/image.dart' as img;

final _transparentWhite = img.ColorRgba8(255, 255, 255, 0);

Future<void> main(List<String> arguments) async {
  final root = _rootFrom(arguments);
  await _writeSources(
    root,
    _decode('$root/assets/images/logo.png'),
    'assets/icon',
  );
  await _writeSources(
    root,
    _decode('$root/assets/images/logo-dev.png'),
    'assets/icon/dev',
  );
}

Future<void> _writeSources(
  String root,
  img.Image source,
  String outputDirectory,
) async {
  final compact = _placeSource(
    source,
    canvasSize: 500,
    sourceSize: 212,
    x: 139,
    y: 150,
  );
  final ios = _placeSource(
    source,
    canvasSize: 500,
    sourceSize: 369,
    x: 64,
    y: 80,
  );

  await _writePng(root, '$outputDirectory/icon-512x512.png', compact);
  await _writePng(root, '$outputDirectory/icon-ios.png', ios);
  await _writePng(
    root,
    '$outputDirectory/icon-macos.png',
    _macosSource(source),
  );
  await _writePng(
    root,
    '$outputDirectory/icon-monochrome-512x512.png',
    _monochromeSource(source),
  );
  await _writePng(root, '$outputDirectory/icon-windows.png', source);
}

String _rootFrom(List<String> arguments) {
  if (arguments.isEmpty) return Directory.current.path;
  if (arguments.length == 2 && arguments.first == '--root') {
    return Directory(arguments.last).absolute.path;
  }
  throw ArgumentError('Usage: generate_app_icon_sources.dart [--root <path>]');
}

img.Image _decode(String path) {
  final image = img.decodeImage(File(path).readAsBytesSync());
  if (image == null) throw StateError('Could not decode $path');
  if (image.width != 512 || image.height != 512) {
    throw StateError('The source icon must be 512x512 pixels.');
  }
  return image.convert(numChannels: 4);
}

img.Image _placeSource(
  img.Image source, {
  required int canvasSize,
  required int sourceSize,
  required int x,
  required int y,
}) {
  final canvas = _canvas(canvasSize, _transparentWhite);
  final resized = img.copyResize(
    source,
    width: sourceSize,
    height: sourceSize,
    interpolation: img.Interpolation.linear,
  );
  return img.compositeImage(canvas, resized, dstX: x, dstY: y);
}

img.Image _macosSource(img.Image source) {
  final canvas = _canvas(512, _transparentWhite);
  final shadow = img.Image(width: 512, height: 512, numChannels: 4);
  img.fillRect(
    shadow,
    x1: 51,
    y1: 56,
    x2: 460,
    y2: 465,
    radius: 101,
    color: img.ColorRgba8(0, 0, 0, 90),
  );
  img.gaussianBlur(shadow, radius: 6);
  img.compositeImage(canvas, shadow);
  img.fillRect(
    canvas,
    x1: 51,
    y1: 51,
    x2: 460,
    y2: 460,
    radius: 94,
    color: img.ColorRgba8(255, 255, 255, 255),
  );
  final resized = img.copyResize(
    source,
    width: 253,
    height: 253,
    interpolation: img.Interpolation.linear,
  );
  return img.compositeImage(canvas, resized, dstX: 135, dstY: 129);
}

img.Image _monochromeSource(img.Image source) {
  final monochrome = _placeSource(
    source,
    canvasSize: 512,
    sourceSize: 212,
    x: 147,
    y: 159,
  );
  for (final pixel in monochrome) {
    if (pixel.a > 0) pixel.setRgba(0, 0, 0, pixel.a);
  }
  return monochrome;
}

img.Image _canvas(int size, img.Color color) {
  final canvas = img.Image(width: size, height: size, numChannels: 4);
  return img.fill(canvas, color: color);
}

Future<void> _writePng(String root, String path, img.Image image) async {
  final file = File('$root/$path');
  await file.parent.create(recursive: true);
  await file.writeAsBytes(img.encodePng(image));
}
