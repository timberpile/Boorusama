import 'dart:io';
import 'dart:isolate';

import 'dart:typed_data';

import 'package:image/image.dart' as image;

import 'providers.dart';

final iqdbSignatureQueue = CrossProfileLookupQueue(concurrency: 1);

const iqdbImageByteLimit = 64 * 1024 * 1024;
const _maxPixels = 32 * 1000 * 1000;
const _maxSide = 32768;

// Use the Danbooru IQDB wire layout and Haar transform. Only this signature
// leaves the device. https://github.com/danbooru/iqdb
Future<String?> iqdbSignatureFromFile(String path) => Isolate.run(() async {
  final file = File(path);
  final bytes = BytesBuilder(copy: false);
  await for (final chunk in file.openRead()) {
    if (bytes.length + chunk.length > iqdbImageByteLimit) return null;
    bytes.add(chunk);
  }
  return iqdbSignature(bytes.takeBytes());
});

Future<String?> iqdbSignatureFromBytes(Uint8List bytes) {
  final transferable = TransferableTypedData.fromList([bytes]);
  return Isolate.run(
    () => iqdbSignature(transferable.materialize().asUint8List()),
  );
}

String? iqdbSignature(Uint8List bytes) {
  if (bytes.isEmpty || bytes.length > iqdbImageByteLimit) return null;
  try {
    final decoder = image.findDecoderForData(bytes);
    if (decoder is! image.JpegDecoder &&
        decoder is! image.PngDecoder &&
        decoder is! image.WebPDecoder) {
      return null;
    }
    final info = decoder!.startDecode(bytes);
    if (info == null ||
        info.width < 1 ||
        info.height < 1 ||
        info.width > _maxSide ||
        info.height > _maxSide ||
        info.width * info.height > _maxPixels ||
        decoder.numFrames() > 1 ||
        (info is image.WebPInfo && info.hasAnimation) ||
        (info is image.PngInfo && info.isAnimated)) {
      return null;
    }
    final decoded = decoder.decodeFrame(0);
    return decoded == null ? null : _signature(decoded);
  } catch (_) {
    return null;
  }
}

const _side = 128;
const _coefficientCount = 40;

String _signature(image.Image decoded) {
  final small = image.copyResize(
    decoded,
    width: _side,
    height: _side,
    interpolation: image.Interpolation.average,
  );
  final channels = List.generate(3, (_) => Float64List(_side * _side));
  for (final pixel in small) {
    final i = pixel.y * _side + pixel.x;
    final r = pixel.rNormalized * 255;
    final g = pixel.gNormalized * 255;
    final b = pixel.bNormalized * 255;
    channels[0][i] = 0.299 * r + 0.587 * g + 0.114 * b;
    channels[1][i] = 0.596 * r - 0.275 * g - 0.321 * b;
    channels[2][i] = 0.212 * r - 0.523 * g + 0.311 * b;
  }

  final bytes = ByteData(3 * 8 + 3 * _coefficientCount * 2);
  var coefficientOffset = 3 * 8;
  for (final (channel, values) in channels.indexed) {
    final differences = Float64List(_side ~/ 2);
    for (var row = 0; row < _side; row++) {
      _decompose(values, row * _side, 1, differences);
    }
    for (var column = 0; column < _side; column++) {
      _decompose(values, column, _side, differences);
    }
    bytes.setFloat64(channel * 8, values[0] / (256 * _side));
    final strongest = List.generate(values.length - 1, (i) => i + 1)
      ..sort((a, b) {
        final magnitude = values[b].abs().compareTo(values[a].abs());
        return magnitude == 0 ? a.compareTo(b) : magnitude;
      });
    final coefficients = [
      for (final i in strongest.take(_coefficientCount)) values[i] > 0 ? i : -i,
    ]..sort();
    for (final coefficient in coefficients) {
      bytes.setInt16(coefficientOffset, coefficient);
      coefficientOffset += 2;
    }
  }
  return 'iqdb_${bytes.buffer.asUint8List().map((n) => n.toRadixString(16).padLeft(2, '0')).join()}';
}

void _decompose(
  Float64List values,
  int start,
  int stride,
  Float64List differences,
) {
  var scale = 1.0;
  for (var count = _side; count > 1; count ~/= 2) {
    final half = count ~/ 2;
    scale *= 0.7071;
    for (var i = 0; i < half; i++) {
      final left = start + 2 * i * stride;
      final first = values[left];
      final second = values[left + stride];
      differences[i] = (first - second) * scale;
      values[start + i * stride] = first + second;
    }
    for (var i = 0; i < half; i++) {
      values[start + (half + i) * stride] = differences[i];
    }
  }
  values[start] *= scale;
}
