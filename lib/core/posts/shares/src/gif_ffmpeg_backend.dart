import 'dart:io';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'gif_export_contract.dart';
import 'gif_output_inspection.dart';

/// Runs only local files, never remote URLs or shell command strings.
abstract interface class GifCommandRunner {
  Future<String> probe(List<String> arguments, CancelToken token);
  Future<void> run(
    List<String> arguments,
    CancelToken token, {
    void Function(int milliseconds)? onTime,
  });
}

class FfmpegGifBackend implements GifEncoderBackend, GifTimelineBackend {
  const FfmpegGifBackend(this.runner, {this.rotationReader});

  final GifCommandRunner runner;
  final Future<int?> Function(String path)? rotationReader;

  @override
  Future<GifSourceMetadata> inspect(
    String sourcePath, {
    required CancelToken cancelToken,
  }) async {
    final json = await runner.probe([
      '-v',
      'error',
      '-show_streams',
      '-show_format',
      '-of',
      'json',
      sourcePath,
    ], cancelToken);
    var metadata = gifMetadataFromProbe(json);
    // Apply dimension/duration guards before the platform metadata reader.
    GifExportPlan.fromSource(metadata, mimeType: 'video/mp4');
    if (rotationReader case final readRotation?) {
      final rotation = await readRotation(sourcePath);
      if (cancelToken.isCancelled) {
        throw const GifConversionException(GifConversionFailure.cancelled);
      }
      metadata = gifMetadataFromProbe(json, fallbackRotation: rotation);
    }
    // Validate dimensions/duration before asking the decoder to allocate frames.
    GifExportPlan.fromSource(metadata, mimeType: 'video/mp4');
    // A successful metadata probe alone does not prove a complete video.
    await runner.run([
      '-v',
      'error',
      '-xerror',
      '-threads',
      '1',
      '-i',
      sourcePath,
      '-map',
      '0:v:0',
      '-an',
      '-threads',
      '1',
      '-f',
      'null',
      '-',
    ], cancelToken);
    return metadata;
  }

  @override
  Future<void> createTimeline({
    required String sourcePath,
    required String outputPath,
    required Duration duration,
    required CancelToken cancelToken,
  }) => runner.run([
    '-y',
    '-v',
    'error',
    '-threads',
    '1',
    '-i',
    sourcePath,
    '-vf',
    'fps=${5 / (duration.inMicroseconds / 1000000)},scale=96:56:force_original_aspect_ratio=decrease,pad=96:56:(ow-iw)/2:(oh-ih)/2,tile=5x1',
    '-frames:v',
    '1',
    '-threads',
    '1',
    outputPath,
  ], cancelToken);

  @override
  Future<void> encode(
    GifEncodeRequest request, {
    required CancelToken cancelToken,
    void Function(double?)? onProgress,
  }) => runner.run(
    gifEncodeArguments(request),
    cancelToken,
    onTime: (time) => onProgress?.call(
      (time / request.plan.outputDuration.inMilliseconds).clamp(0, 1),
    ),
  );

  @override
  Future<GifOutputValidation> validateOutput(
    GifEncodeRequest request, {
    required CancelToken cancelToken,
  }) async {
    await runner.run([
      '-v',
      'error',
      '-xerror',
      '-ignore_loop',
      '1',
      '-i',
      request.outputPath,
      '-an',
      '-threads',
      '1',
      '-f',
      'null',
      '-',
    ], cancelToken);
    final result = await compute(_inspectOutputFile, request.outputPath);
    if (cancelToken.isCancelled) {
      throw const GifConversionException(GifConversionFailure.cancelled);
    }
    return result;
  }
}

Future<GifOutputValidation> _inspectOutputFile(String path) async =>
    inspectGifOutput(await File(path).readAsBytes());

GifSourceMetadata gifMetadataFromProbe(String output, {int? fallbackRotation}) {
  final json = jsonDecode(output);
  if (json is! Map<String, dynamic>) {
    throw const GifConversionException(GifConversionFailure.unsupportedSource);
  }
  final streams = json['streams'];
  final video = streams is List
      ? streams
            .whereType<Map<String, dynamic>>()
            .where(
              (stream) => stream['codec_type'] == 'video',
            )
            .firstOrNull
      : null;
  if (video == null) {
    throw const GifConversionException(GifConversionFailure.unsupportedSource);
  }
  final format = json['format'];
  final seconds =
      _number(video['duration']) ??
      (format is Map ? _number(format['duration']) : null);
  double? rotation;
  final sideData = video['side_data_list'];
  if (sideData is List) {
    for (final side in sideData.whereType<Map>()) {
      rotation ??= _number(side['rotation']);
    }
  }
  final tags = video['tags'];
  rotation ??= tags is Map ? _number(tags['rotate']) : null;
  // FFprobe's display matrix reports counterclockwise rotation. Encoding uses
  // FFmpeg's autorotation; the plan only needs its normalized display axes.
  final degrees =
      (((rotation?.round() ?? fallbackRotation ?? 0) % 360) + 360) % 360;
  // FFprobe uses 0:1 for an unspecified pixel aspect ratio. FFmpeg treats
  // these frames as square pixels; keep the preflight consistent with it.
  final sar = video['sample_aspect_ratio'];
  return GifSourceMetadata(
    duration: seconds != null && seconds.isFinite && seconds > 0
        ? Duration(microseconds: (seconds * 1000000).round())
        : null,
    complete: true, // Returned to the caller only after full video decoding.
    width: (video['width'] as num?)?.toInt(),
    height: (video['height'] as num?)?.toInt(),
    rotationDegrees: degrees,
    sampleAspectRatio: sar == null || sar == 'N/A' || sar == '0:1'
        ? 1
        : _ratio(sar, ':'),
    frameRate:
        _ratio(video['avg_frame_rate'], '/') ??
        _ratio(video['r_frame_rate'], '/'),
  );
}

double? _number(Object? value) => switch (value) {
  num() => value.toDouble(),
  String() => double.tryParse(value),
  _ => null,
};

double? _ratio(Object? value, String separator) {
  if (value is! String) return null;
  final parts = value.split(separator);
  if (parts.length != 2) return _number(value);
  final numerator = _number(parts[0]);
  final denominator = _number(parts[1]);
  if (numerator == null || denominator == null || denominator == 0) return null;
  final result = numerator / denominator;
  return result.isFinite && result > 0 ? result : null;
}

List<String> gifEncodeArguments(GifEncodeRequest request) {
  final plan = request.plan;
  // Per-frame palettes avoid palettegen buffering the whole animation.
  final filter =
      'trim=duration=${plan.duration.inMicroseconds / 1000000},'
      'setpts=PTS-STARTPTS,fps=${plan.encodedSourceFrameRate},'
      'settb=1/100,setpts=round(N*100/${plan.encodedPlaybackFrameRate}),'
      'scale=${plan.width}:${plan.height}:flags=lanczos,setsar=1,'
      'split[frames][colors];[colors]palettegen=stats_mode=single[palette];'
      '[frames][palette]paletteuse=new=1:dither=sierra2_4a';
  return [
    '-y',
    '-v',
    'error',
    '-xerror',
    '-threads',
    '1',
    '-ss',
    '${plan.start.inMicroseconds / 1000000}',
    '-i',
    request.sourcePath,
    '-an',
    '-filter_complex_threads',
    '1',
    '-filter_complex',
    filter,
    '-threads',
    '1',
    '-fps_mode',
    'passthrough',
    '-enc_time_base',
    '1:100',
    '-loop',
    '0',
    '-final_delay',
    '${(100 / plan.encodedPlaybackFrameRate).round().clamp(1, 100)}',
    '-fs',
    '${request.maxOutputBytes + 1}',
    '-f',
    'gif',
    request.outputPath,
  ];
}
