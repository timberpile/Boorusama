import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final localMp4RestartedTimelineProvider =
    Provider<Future<RestartedLocalMp4Timeline?> Function(File)>(
      (_) => inspectLocalMp4Timeline,
    );

class RestartedLocalMp4Timeline {
  const RestartedLocalMp4Timeline({this.firstStreamLength});

  /// The byte length of the first stream when the following stream is identical.
  final int? firstStreamLength;
}

Future<RestartedLocalMp4Timeline?> inspectLocalMp4Timeline(File file) =>
    compute(_inspectTimeline, file.path);

RestartedLocalMp4Timeline? _inspectTimeline(String path) {
  try {
    final file = File(path).openSync();
    try {
      final length = file.lengthSync();
      final boxes = _Mp4Boxes(file);
      _FragmentStart? previousStart;
      _FragmentStart? start;
      int? fileTypeOffset;
      int? streamOffset;
      int? previousStreamOffset;
      var hasFragmentedInit = false;

      // A second complete fragmented MP4 with a restarted sequence is a
      // separate timeline inside the file. A single fragmented MP4 can have
      // any number of fragments or segment indexes with one initialization.
      for (final box in boxes.read(0, length)) {
        switch (box.type) {
          case 'ftyp':
            fileTypeOffset = box.end - box.payload >= 8 ? box.start : null;
            hasFragmentedInit = false;
            start = null;
          case 'moov' when fileTypeOffset != null:
            streamOffset = fileTypeOffset;
            fileTypeOffset = null;
            hasFragmentedInit = boxes
                .read(box.payload, box.end)
                .any((child) => child.type == 'mvex');
            if (previousStart == null && !hasFragmentedInit) {
              return null;
            }
          case 'moof' when hasFragmentedInit:
            hasFragmentedInit = false;
            start = boxes.fragmentStart(box);
          case 'mdat' when start != null && box.payload < box.end:
            if (previousStart != null &&
                start.sequence <= previousStart.sequence &&
                start.trackId == previousStart.trackId &&
                previousStart.decodeTime == 0 &&
                start.decodeTime == 0) {
              return RestartedLocalMp4Timeline(
                firstStreamLength:
                    previousStreamOffset == 0 &&
                        streamOffset != null &&
                        _hasIdenticalHalves(file, length, streamOffset)
                    ? streamOffset
                    : null,
              );
            }
            previousStart = start;
            previousStreamOffset = streamOffset;
            start = null;
        }
      }
      return null;
    } finally {
      file.closeSync();
    }
  } on FileSystemException {
    return null;
  } on FormatException {
    return null;
  }
}

bool _hasIdenticalHalves(RandomAccessFile file, int length, int midpoint) {
  // Compare payload bytes only for detected restarts and bound the extra I/O.
  const maxComparisonBytes = 64 * 1024 * 1024;
  if (length > maxComparisonBytes || midpoint != length - midpoint) {
    return false;
  }

  const chunkSize = 64 * 1024;
  final first = Uint8List(chunkSize);
  final second = Uint8List(chunkSize);
  try {
    for (var start = 0; start < midpoint; start += chunkSize) {
      final count = (midpoint - start).clamp(0, chunkSize);
      file.setPositionSync(start);
      if (file.readIntoSync(first, 0, count) != count) return false;
      file.setPositionSync(midpoint + start);
      if (file.readIntoSync(second, 0, count) != count) return false;
      if (!listEquals(first, second)) return false;
    }
    return true;
  } on FileSystemException {
    return false;
  }
}

typedef _Box = ({String type, int start, int payload, int end});
typedef _FragmentStart = ({int sequence, int trackId, int decodeTime});

class _Mp4Boxes {
  _Mp4Boxes(this.file);

  final RandomAccessFile file;
  final _buffer = Uint8List(8);
  late final _numbers = ByteData.sublistView(_buffer);
  // Bound the work for very long or malformed files. Payloads are skipped.
  var _remainingBoxes = 4096;

  Iterable<_Box> read(int start, int end) sync* {
    var offset = start;
    while (offset < end) {
      if (_remainingBoxes-- == 0) {
        throw const FormatException('MP4 box read limit reached');
      }
      _readHeader(offset, end);
      var size = _numbers.getUint32(0);
      final type = String.fromCharCodes(_buffer, 4);
      var headerSize = 8;
      if (size == 1) {
        _readHeader(offset + 8, end);
        size = _numbers.getUint64(0);
        headerSize = 16;
      } else if (size == 0) {
        size = end - offset;
      }
      if (size < headerSize || size > end - offset) {
        throw const FormatException('Invalid MP4 box size');
      }
      yield (
        type: type,
        start: offset,
        payload: offset + headerSize,
        end: offset + size,
      );
      offset += size;
    }
  }

  _FragmentStart? fragmentStart(_Box fragment) {
    int? sequence;
    for (final box in read(fragment.payload, fragment.end)) {
      switch (box.type) {
        case 'mfhd':
          _readHeader(box.payload, box.end);
          if (_numbers.getUint32(0) != 0) return null;
          sequence = _numbers.getUint32(4);
        case 'traf' when sequence != null:
          final track = _trackStart(box);
          if (track != null) {
            return (
              sequence: sequence,
              trackId: track.trackId,
              decodeTime: track.decodeTime,
            );
          }
      }
    }
    return null;
  }

  ({int trackId, int decodeTime})? _trackStart(_Box track) {
    int? trackId;
    for (final box in read(track.payload, track.end)) {
      switch (box.type) {
        case 'tfhd':
          _readHeader(box.payload, box.end);
          trackId = _numbers.getUint32(4);
        case 'tfdt' when trackId != null:
          _readHeader(box.payload, box.end);
          final int decodeTime;
          switch (_numbers.getUint8(0)) {
            case 0:
              decodeTime = _numbers.getUint32(4);
            case 1:
              _readHeader(box.payload + 4, box.end);
              decodeTime = _numbers.getUint64(0);
            default:
              return null;
          }
          return decodeTime >= 0
              ? (trackId: trackId, decodeTime: decodeTime)
              : null;
      }
    }
    return null;
  }

  void _readHeader(int offset, int end) {
    if (end - offset < _buffer.length) {
      throw const FormatException('Truncated MP4 box header');
    }
    file.setPositionSync(offset);
    if (file.readIntoSync(_buffer) != _buffer.length) {
      throw const FormatException('Truncated MP4 box header');
    }
  }
}
