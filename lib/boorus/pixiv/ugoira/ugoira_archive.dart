import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:booru_clients/pixiv.dart';

const pixivUgoiraArchiveByteLimit = 64 * 1024 * 1024;
const _expandedByteLimit = 64 * 1024 * 1024;
const _frameByteLimit = 8 * 1024 * 1024;
const _frameCountLimit = 500;

final _frameName = RegExp(
  r'^[a-zA-Z0-9_-]+\.(jpg|jpeg|png)$',
  caseSensitive: false,
);

class PixivUgoiraAnimation {
  const PixivUgoiraAnimation(this.frames, this.frameEnds);

  final List<Uint8List> frames;
  final List<int> frameEnds;

  int get durationMilliseconds => frameEnds.last;

  int frameAt(int elapsedMilliseconds) {
    final position = elapsedMilliseconds % durationMilliseconds;
    var first = 0;
    var last = frameEnds.length - 1;
    while (first < last) {
      final middle = (first + last) ~/ 2;
      if (position < frameEnds[middle]) {
        last = middle;
      } else {
        first = middle + 1;
      }
    }
    return first;
  }
}

typedef PixivUgoiraArchiveData = ({
  Uint8List zip,
  List<PixivUgoiraFrame> frames,
});

PixivUgoiraAnimation decodePixivUgoiraArchive(PixivUgoiraArchiveData data) {
  if (data.zip.isEmpty ||
      data.zip.length > pixivUgoiraArchiveByteLimit ||
      data.frames.isEmpty ||
      data.frames.length > _frameCountLimit) {
    throw const FormatException('Invalid Ugoira archive or frame count');
  }

  final names = <String>{};
  final frameEnds = <int>[];
  var duration = 0;
  for (final frame in data.frames) {
    final name = frame.file;
    final delay = frame.delay;
    if (name == null ||
        !_frameName.hasMatch(name) ||
        !names.add(name) ||
        delay == null ||
        delay <= 0 ||
        delay > Duration.millisecondsPerDay - duration) {
      throw const FormatException('Invalid Ugoira frame metadata');
    }
    duration += delay;
    frameEnds.add(duration);
  }

  // Inspect headers before inflating anything. ZipDecoder's symlink handling
  // can decode entry contents while constructing the archive.
  final directory = ZipDirectory()..read(InputMemoryStream(data.zip));
  if (directory.fileHeaders.length != names.length) {
    throw const FormatException('Ugoira archive does not match its metadata');
  }

  final headers = <String, ZipFileHeader>{};
  var expandedBytes = 0;
  var compressedBytes = 0;
  for (final header in directory.fileHeaders) {
    final file = header.file;
    final type = (header.externalFileAttributes >> 16) & 0xf000;
    if (!names.contains(header.filename) ||
        headers.containsKey(header.filename) ||
        file == null ||
        file.filename != header.filename ||
        (type != 0 && type != 0x8000) ||
        (header.generalPurposeBitFlag & 1) != 0 ||
        (file.flags & 1) != 0 ||
        (header.compressionMethod != 0 && header.compressionMethod != 8) ||
        file.compressionMethod !=
            (header.compressionMethod == 0
                ? CompressionType.none
                : CompressionType.deflate) ||
        header.compressedSize <= 0 ||
        header.uncompressedSize <= 0 ||
        header.uncompressedSize > _frameByteLimit) {
      throw const FormatException('Invalid Ugoira ZIP entry');
    }
    headers[header.filename] = header;
    expandedBytes += header.uncompressedSize;
    compressedBytes += header.compressedSize;
    if (expandedBytes > _expandedByteLimit ||
        compressedBytes > data.zip.length) {
      throw const FormatException('Ugoira archive exceeds its size limit');
    }
  }

  return PixivUgoiraAnimation(
    [
      for (final frame in data.frames) _readFrame(headers[frame.file]!),
    ],
    frameEnds,
  );
}

Uint8List _readFrame(ZipFileHeader header) {
  final output = _BoundedFrameOutput(header.uncompressedSize);
  header.file!.decompress(output);
  final bytes = output.getBytes();
  if (bytes.length != header.uncompressedSize ||
      getCrc32(bytes) != header.crc32) {
    throw const FormatException('Corrupt Ugoira ZIP entry');
  }
  final jpeg =
      bytes.length >= 3 &&
      bytes[0] == 0xff &&
      bytes[1] == 0xd8 &&
      bytes[2] == 0xff;
  const pngSignature = [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a];
  final png =
      bytes.length >= pngSignature.length &&
      Iterable<int>.generate(pngSignature.length).every(
        (index) => bytes[index] == pngSignature[index],
      );
  if (header.filename.toLowerCase().endsWith('.png') ? !png : !jpeg) {
    throw const FormatException('Unsupported Ugoira frame image');
  }
  return bytes;
}

class _BoundedFrameOutput extends OutputMemoryStream {
  _BoundedFrameOutput(this.limit) : super(size: limit);

  final int limit;

  void _check(int count) {
    if (count < 0 || count > limit - length) {
      throw const FormatException('Ugoira ZIP entry exceeds its declared size');
    }
  }

  @override
  void writeByte(int value) {
    _check(1);
    super.writeByte(value);
  }

  @override
  void writeBytes(List<int> bytes, {int? length}) {
    _check(length ?? bytes.length);
    super.writeBytes(bytes, length: length);
  }

  @override
  void writeStream(InputStream stream) {
    _check(stream.length);
    super.writeStream(stream);
  }

  @override
  void writeBackReference(int distance, int count) {
    _check(count);
    super.writeBackReference(distance, count);
  }
}
