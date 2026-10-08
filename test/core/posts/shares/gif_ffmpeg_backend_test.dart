// ignore_for_file: avoid_slow_async_io
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:boorusama/core/posts/shares/src/gif_conversion_service.dart';
import 'package:boorusama/core/posts/shares/src/gif_export_contract.dart';
import 'package:boorusama/core/posts/shares/src/gif_ffmpeg_backend.dart';
import 'package:boorusama/core/posts/shares/src/gif_output_inspection.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:boorusama/core/posts/shares/src/gif_ffmpeg_runner.dart';
import 'package:image/image.dart' as image;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Android rotation uses the same angle convention as FFprobe', () async {
    const channel = MethodChannel('boorusama/gif_metadata');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'rotation');
      expect(call.arguments, {'path': '/cache/source.mp4'});
      return 270;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    expect(await readAndroidGifRotation('/cache/source.mp4'), 90);
  });

  test(
    'probe metadata keeps rotation, pixel aspect ratio and fractional FPS',
    () {
      final metadata = gifMetadataFromProbe(
        jsonEncode({
          'format': {'duration': '3.25'},
          'streams': [
            {
              'codec_type': 'video',
              'width': 1920,
              'height': 1080,
              'sample_aspect_ratio': '4:3',
              'avg_frame_rate': '24000/1001',
              'side_data_list': [
                {'rotation': -90},
              ],
            },
          ],
        }),
      );
      final plan = GifExportPlan.fromSource(metadata, mimeType: 'video/mp4');
      expect(metadata.frameRate, closeTo(23.976, .001));
      expect(plan.rotationDegrees, 270);
      expect((plan.width, plan.height), (203, 480));
      expect(plan.duration, const Duration(milliseconds: 3250));
    },
  );

  test(
    'native rotation fills omitted side data without overriding reported rotation',
    () {
      final withoutRotation = jsonEncode({
        'streams': [
          {'codec_type': 'video', 'width': 160, 'height': 90},
        ],
        'format': {'duration': '2'},
      });
      expect(
        gifMetadataFromProbe(
          withoutRotation,
          fallbackRotation: 90,
        ).rotationDegrees,
        90,
      );
      final withRotation = jsonEncode({
        'streams': [
          {
            'codec_type': 'video',
            'side_data_list': [
              {'rotation': -90},
            ],
          },
        ],
      });
      expect(
        gifMetadataFromProbe(withRotation, fallbackRotation: 0).rotationDegrees,
        270,
      );
    },
  );

  test('unspecified pixel aspect ratio uses square pixels', () {
    final metadata = gifMetadataFromProbe(
      jsonEncode({
        'streams': [
          {
            'codec_type': 'video',
            'width': 726,
            'height': 720,
            'sample_aspect_ratio': '0:1',
            'duration': '13',
          },
        ],
      }),
    );
    final plan = GifExportPlan.fromSource(metadata, mimeType: 'video/mp4');
    expect(metadata.sampleAspectRatio, 1);
    expect((plan.width, plan.height), (480, 476));
  });

  test('missing decoder duration and dimensions remain unknown', () {
    final metadata = gifMetadataFromProbe(
      jsonEncode({
        'streams': [
          {'codec_type': 'video', 'avg_frame_rate': '0/0'},
        ],
      }),
    );
    expect(metadata.duration, isNull);
    expect(metadata.frameRate, isNull);
    expect(metadata.width, isNull);
  });

  test(
    'whole-file inspection rejects a missing trailer and corrupt frames',
    () {
      final frame = image.Image(width: 16, height: 16);
      final encoder = image.GifEncoder()
        ..addFrame(frame, duration: 8)
        ..addFrame(frame, duration: 9);
      final bytes = encoder.finish()!;
      final valid = inspectGifOutput(bytes);
      expect(valid.fullDecodeSucceeded, isTrue);
      expect(valid.infiniteLoop, isTrue);
      expect(valid.frameDelayCentiseconds, [8, 9]);
      expect(
        inspectGifOutput(
          Uint8List.sublistView(bytes, 0, bytes.length - 1),
        ).fullDecodeSucceeded,
        isFalse,
      );
      expect(
        inspectGifOutput(
          Uint8List.fromList([71, 73, 70, 56, 57, 97, 59]),
        ).fullDecodeSucceeded,
        isFalse,
      );
    },
  );

  for (final (extension, codec) in [
    ('mp4', 'libx264'),
    ('webm', 'libvpx-vp9'),
  ]) {
    test(
      'real $extension conversion produces a looping plan-accurate GIF',
      () async {
        final directory = await Directory.systemTemp.createTemp('gif-real-');
        addTearDown(() => directory.delete(recursive: true));
        final source = "${directory.path}/input with space's.$extension";
        await _fixture(source, codec);
        final backend = FfmpegGifBackend(_ProcessRunner());
        final token = CancelToken();
        final metadata = await backend.inspect(source, cancelToken: token);
        final plan = GifExportPlan.fromSource(
          metadata,
          mimeType: 'video/$extension',
        );
        final request = GifEncodeRequest(
          sourcePath: source,
          outputPath: '${directory.path}/result.gif',
          plan: plan,
        );
        await backend.encode(request, cancelToken: token);
        final validation = await backend.validateOutput(
          request,
          cancelToken: token,
        );
        expect(gifOutputMatchesPlan(validation, plan), isTrue);
        expect(validation.canvasWidth, 480);
        expect(validation.canvasHeight, 270);
        expect(validation.frameCount, 24);
        expect(await File(source).exists(), isTrue);
      },
      skip: !File('/usr/bin/ffmpeg').existsSync(),
    );
  }

  test(
    'real conversion accepts a source and selected clip beyond both former limits',
    () async {
      final directory = await Directory.systemTemp.createTemp('gif-long-real-');
      addTearDown(() => directory.delete(recursive: true));
      final source = '${directory.path}/source.mp4';
      await _fixture(source, 'libx264', duration: 32);
      final backend = FfmpegGifBackend(_ProcessRunner());
      final token = CancelToken();
      final metadata = await backend.inspect(source, cancelToken: token);
      final plan = GifExportPlan.fromSource(
        metadata,
        mimeType: 'video/mp4',
        settings: const GifExportSettings(
          start: Duration(seconds: 6),
          duration: Duration(seconds: 26),
          resolution: GifResolution.original,
          frameRate: GifFrameRate.original,
        ),
      );
      final request = GifEncodeRequest(
        sourcePath: source,
        outputPath: '${directory.path}/result.gif',
        plan: plan,
      );
      await backend.encode(request, cancelToken: token);
      final validation = await backend.validateOutput(
        request,
        cancelToken: token,
      );
      expect(gifOutputMatchesPlan(validation, plan), isTrue);
      expect(validation.frameCount, 624);
      expect(validation.frameDelayCentiseconds!.reduce((a, b) => a + b), 2600);
    },
    skip: !File('/usr/bin/ffmpeg').existsSync(),
  );

  test('filmstrip covers the inspected source without changing it', () async {
    final directory = await Directory.systemTemp.createTemp('gif-filmstrip-');
    addTearDown(() => directory.delete(recursive: true));
    final source = '${directory.path}/source.mp4';
    await _fixture(source, 'libx264');
    final before = await File(source).readAsBytes();
    final timeline = '${directory.path}/timeline.png';
    await FfmpegGifBackend(_ProcessRunner()).createTimeline(
      sourcePath: source,
      outputPath: timeline,
      duration: const Duration(seconds: 2),
      cancelToken: CancelToken(),
    );
    final decoded = image.decodePng(await File(timeline).readAsBytes());
    expect((decoded!.width, decoded.height), (480, 56));
    expect(await File(source).readAsBytes(), before);
  }, skip: !File('/usr/bin/ffmpeg').existsSync());

  for (final (fps, playback) in [
    (24.0, 6),
    (12.0, 24),
    (60.0, 240),
    (24000 / 1001, 24),
  ]) {
    test(
      'real GIF timing for $fps source FPS and $playback playback FPS',
      () async {
        final directory = await Directory.systemTemp.createTemp('gif-speed-');
        addTearDown(() => directory.delete(recursive: true));
        final source = '${directory.path}/source.mp4';
        await _fixture(source, 'libx264', fps: fps);
        final backend = FfmpegGifBackend(_ProcessRunner());
        final metadata = await backend.inspect(
          source,
          cancelToken: CancelToken(),
        );
        final plan = GifExportPlan.fromSource(
          metadata,
          mimeType: 'video/mp4',
          settings: GifExportSettings(
            start: const Duration(milliseconds: 250),
            duration: const Duration(milliseconds: 1500),
            resolution: GifResolution.original,
            frameRate: GifFrameRate.original,
            sourceFrameRate: fps,
            playbackFrameRate: playback,
          ),
        );
        final request = GifEncodeRequest(
          sourcePath: source,
          outputPath: '${directory.path}/result.gif',
          plan: plan,
        );
        await backend.encode(request, cancelToken: CancelToken());
        final validation = await backend.validateOutput(
          request,
          cancelToken: CancelToken(),
        );
        expect(
          gifOutputMatchesPlan(validation, plan),
          isTrue,
          reason:
              'Frames: ${validation.frameCount}, delays: ${validation.frameDelayCentiseconds}',
        );
        expect(
          validation.frameDelayCentiseconds!.every((delay) => delay >= 1),
          isTrue,
        );
      },
      skip: !File('/usr/bin/ffmpeg').existsSync(),
    );
  }

  test('a downloaded-looking truncated source fails full decode', () async {
    final directory = await Directory.systemTemp.createTemp('gif-truncated-');
    addTearDown(() => directory.delete(recursive: true));
    final path = '${directory.path}/source.mp4';
    await _fixture(path, 'libx264');
    final bytes = await File(path).readAsBytes();
    await File(path).writeAsBytes(bytes.sublist(0, bytes.length - 1000));
    await expectLater(
      FfmpegGifBackend(
        _ProcessRunner(),
      ).inspect(path, cancelToken: CancelToken()),
      throwsA(isA<GifConversionException>()),
    );
  }, skip: !File('/usr/bin/ffmpeg').existsSync());
}

Future<void> _fixture(
  String path,
  String codec, {
  double fps = 24,
  int duration = 2,
}) async {
  final result = await Process.run('ffmpeg', [
    '-y',
    '-v',
    'error',
    '-f',
    'lavfi',
    '-i',
    'testsrc2=size=160x90:rate=$fps:duration=$duration',
    '-c:v',
    codec,
    if (codec == 'libx264') ...['-movflags', '+faststart'],
    path,
  ]);
  expect(result.exitCode, 0, reason: '${result.stderr}');
}

class _ProcessRunner implements GifCommandRunner {
  @override
  Future<String> probe(List<String> args, CancelToken token) =>
      _execute('ffprobe', args, token);

  @override
  Future<void> run(
    List<String> args,
    CancelToken token, {
    void Function(int)? onTime,
  }) async {
    await _execute('ffmpeg', args, token);
  }

  Future<String> _execute(
    String executable,
    List<String> args,
    CancelToken token,
  ) async {
    if (token.isCancelled) {
      throw const GifConversionException(GifConversionFailure.cancelled);
    }
    final process = await Process.start(executable, args);
    var finished = false;
    unawaited(
      token.whenCancel.then((_) {
        if (!finished) process.kill();
      }),
    );
    final stdout = process.stdout.transform(utf8.decoder).join();
    final stderr = process.stderr.transform(utf8.decoder).join();
    final exit = await process.exitCode;
    finished = true;
    final output = await stdout;
    final error = await stderr;
    if (token.isCancelled) {
      throw const GifConversionException(GifConversionFailure.cancelled);
    }
    if (exit != 0) {
      throw GifConversionException(GifConversionFailure.encoder, cause: error);
    }
    return output;
  }
}
