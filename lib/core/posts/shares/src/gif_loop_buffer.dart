import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';

import 'gif_conversion_service.dart';
import 'gif_editor_selection.dart';
import 'gif_loop_frame_clock.dart';
import 'gif_loop_refinement_service.dart';

class GifLoopBuffer {
  GifLoopBuffer(this.images, this.start, this.clock);
  final List<ui.Image> images;
  final Duration start;
  final GifLoopFrameClock clock;
  void dispose() {
    for (final image in images) {
      image.dispose();
    }
  }
}

/// Preview-only regional decode: never uses or changes the final GIF encoder.
/// At most 24 MiB of raw pixels plus their ui.Image copies; native decoder
/// allocations are additional and remain subject to the source dimension guard.
class GifLoopBufferDecoder {
  const GifLoopBufferDecoder(this.runner);
  final GifLoopCommandRunner runner;
  static const maxBytes = 24 * 1024 * 1024;
  static const maxFrames = 600;

  Future<GifLoopBuffer?> decode(
    GifPreparedSource source,
    Duration start,
    Duration end,
    CancelToken token,
  ) async {
    final count =
        (((end - start).inMicroseconds / 1000000) * source.metadata.frameRate!)
            .ceil() +
        2;
    if (count < 2 || count > maxFrames || token.isCancelled) return null;
    final selection = GifEditorSelection.initial(
      source.metadata,
      source.lease.mimeType,
    );
    final (originalWidth, originalHeight) = selection.originalDimensions;
    final scale = math.min(
      1,
      math.min(
        360 / math.max(originalWidth, originalHeight),
        math.sqrt(maxBytes / (count * originalWidth * originalHeight * 4)),
      ),
    );
    final width = math.max(1, (originalWidth * scale).floor());
    final height = math.max(1, (originalHeight * scale).floor());
    final frameBytes = width * height * 4;
    if (math.max(width, height) < 96) return null;
    source.lease.retain();
    Directory? directory;
    final images = <ui.Image>[];
    GifLoopBuffer? result;
    final deadline = Timer(const Duration(seconds: 20), () => token.cancel());
    try {
      directory = await File(
        source.lease.path,
      ).parent.createTemp('gif-loop-preview-');
      final output = File('${directory.path}/frames.rgba');
      final log = await runner.runWithOutput(
        gifLoopBufferArguments(
          source.lease.path,
          output.path,
          start,
          end,
          width,
          height,
        ),
        token,
      );
      if (token.isCancelled) return null;
      final length = await output.length();
      if (length == 0 || length > maxBytes || length % frameBytes != 0) {
        return null;
      }
      final timestamps = gifLoopBufferTimestamps(log, length ~/ frameBytes);
      if (timestamps.length < 2 ||
          timestamps.first < start.inMicroseconds ||
          timestamps.last >= end.inMicroseconds) {
        return null;
      }
      // Keep the selected duration, including a fractional leading frame.
      // The first retained image is displayed from trim start; following images
      // keep their original PTS. Frame-aligned refinement needs no adjustment.
      final first = start.inMicroseconds;
      final clock = GifLoopFrameClock(
        [0, for (final time in timestamps.skip(1)) time - first],
        end.inMicroseconds - first,
      );
      final bytes = await output.readAsBytes();
      for (var i = 0; i < timestamps.length; i++) {
        if (token.isCancelled) return null;
        final pixels = await ui.ImmutableBuffer.fromUint8List(
          Uint8List.sublistView(bytes, i * frameBytes, (i + 1) * frameBytes),
        );
        ui.ImageDescriptor? descriptor;
        ui.Codec? codec;
        try {
          descriptor = ui.ImageDescriptor.raw(
            pixels,
            width: width,
            height: height,
            pixelFormat: ui.PixelFormat.rgba8888,
          );
          codec = await descriptor.instantiateCodec();
          images.add((await codec.getNextFrame()).image);
        } finally {
          codec?.dispose();
          descriptor?.dispose();
          pixels.dispose();
        }
      }
      if (token.isCancelled) return null;
      result = GifLoopBuffer(
        List.of(images),
        Duration(microseconds: first),
        clock,
      );
      images.clear(); // Ownership moves to the preview backend.
      return result;
    } finally {
      deadline.cancel();
      for (final image in images) {
        image.dispose();
      }
      try {
        try {
          if (directory != null) await directory.delete(recursive: true);
        } finally {
          await source.lease.release();
        }
      } catch (_) {
        result?.dispose();
        rethrow;
      }
    }
  }
}

List<String> gifLoopBufferArguments(
  String source,
  String output,
  Duration start,
  Duration end,
  int width,
  int height,
) {
  final a = (start.inMicroseconds / 1000000).toStringAsFixed(6);
  final b = (end.inMicroseconds / 1000000).toStringAsFixed(6);
  return [
    '-y',
    '-hide_banner',
    '-nostdin',
    '-loglevel',
    'info',
    '-xerror',
    '-threads',
    '1',
    '-copyts',
    '-start_at_zero',
    '-ss',
    a,
    '-t',
    ((end - start).inMicroseconds / 1000000).toStringAsFixed(6),
    '-i',
    source,
    '-map',
    '0:v:0',
    '-an',
    '-sn',
    '-dn',
    '-vf',
    'trim=start=$a:end=$b,scale=$width:$height:flags=area,format=rgba,showinfo=checksum=0',
    '-fps_mode',
    'passthrough',
    '-frames:v',
    '${GifLoopBufferDecoder.maxFrames + 1}',
    '-fs',
    '${GifLoopBufferDecoder.maxBytes + 1}',
    '-threads',
    '1',
    '-f',
    'rawvideo',
    '-pix_fmt',
    'rgba',
    output,
  ];
}

/// Parse the same decoder session, retaining rational time-base precision.
List<int> gifLoopBufferTimestamps(String log, int count) {
  final bases = RegExp(
    r'config in time_base:\s*(\d+)/(\d+)',
  ).allMatches(log).toList();
  final records = RegExp(
    r'\bn:\s*(\d+)\s+pts:\s*(-?\d+)\s+pts_time:',
  ).allMatches(log).toList();
  if (bases.length != 1 ||
      count > GifLoopBufferDecoder.maxFrames ||
      records.length != count) {
    throw const FormatException('Unpaired preview frames');
  }
  final n = int.parse(bases.single.group(1)!);
  final d = int.parse(bases.single.group(2)!);
  if (n <= 0 || d <= 0) {
    throw const FormatException('Invalid preview time base');
  }
  final timestamps = <int>[];
  for (var i = 0; i < records.length; i++) {
    final ticks = int.parse(records[i].group(2)!);
    final time = (ticks * n * 1000000 + d ~/ 2) ~/ d;
    if (int.parse(records[i].group(1)!) != i ||
        ticks < 0 ||
        (timestamps.isNotEmpty && time <= timestamps.last)) {
      throw const FormatException('Invalid preview frame order');
    }
    timestamps.add(time);
  }
  return timestamps;
}
