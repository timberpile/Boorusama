// ignore_for_file: avoid_slow_async_io
import 'dart:async';
import 'dart:io';

import 'package:boorusama/core/posts/shares/src/gif_conversion_service.dart';
import 'package:boorusama/core/posts/shares/src/gif_background_execution.dart';
import 'package:boorusama/core/posts/shares/src/gif_export_contract.dart';
import 'package:boorusama/core/posts/shares/src/gif_editor_controller.dart';
import 'package:boorusama/core/posts/shares/src/share_media_preparation.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

void main() {
  late Directory root;
  late HttpServer server;
  late ShareMediaPreparation preparation;
  late _FakeGifEncoder encoder;
  var downloads = 0;

  setUp(() async {
    downloads = 0;
    root = await Directory.systemTemp.createTemp('gif-conversion-test-');
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      downloads++;
      request.response.headers.contentType = ContentType('video', 'mp4');
      request.response.add([0, 0, 0, 8, 102, 116, 121, 112]);
      await request.response.close();
    });
    preparation = ShareMediaPreparation(
      rootPath: root.path,
      dio: Dio(),
      cachedBytes: (_) async => null,
    );
    encoder = _FakeGifEncoder();
  });
  tearDown(() async {
    await server.close(force: true);
    await root.delete(recursive: true);
  });

  Future<ShareMediaLease> convert({
    GifExportSettings? settings,
    CancelToken? cancelToken,
    void Function(GifConversionProgress)? onProgress,
  }) =>
      GifConversionService(
        preparation: preparation,
        backend: encoder,
      ).convert(
        sourceUrl: 'http://127.0.0.1:${server.port}/post.mp4',
        headers: const {},
        playbackPosition: const Duration(seconds: 26),
        settings: settings,
        cancelToken: cancelToken,
        onProgress: onProgress,
      );

  Future<GifPreparedSource> prepare(GifConversionService service) =>
      service.prepareSource(
        sourceUrl: 'http://127.0.0.1:${server.port}/post.mp4',
        headers: const {},
        cancelToken: CancelToken(),
      );

  test(
    'adjusting and repeating conversions downloads and inspects only once',
    () async {
      encoder.onValidate = (request, _) async => _matchingEvidence(request);
      final service = GifConversionService(
        preparation: preparation,
        backend: encoder,
      );
      final source = await prepare(service);
      final controller = GifEditorController(source: source, service: service);
      await controller.create();
      expect(controller.phase, GifEditorPhase.preview);
      final first = controller.result!.path;
      await controller.adjust();
      expect(await File(first).exists(), isFalse);
      controller.update(
        controller.selection.copyWith(
          resolution: GifResolution.px480,
          sourceFrameRate: 12,
          speedPreset: .5,
        ),
      );
      await controller.create();
      expect(controller.phase, GifEditorPhase.preview);
      expect(encoder.request!.plan.width, 480);
      expect(encoder.request!.plan.playbackFrameRate, 6);
      expect(downloads, 1);
      expect(encoder.inspections, 1);
      expect(await File(source.lease.path).exists(), isTrue);
      await controller.adjust();
      controller.dispose();
      await source.release();
      expect(
        await Directory('${root.path}/boorusama-share').list().toList(),
        isEmpty,
      );
    },
  );

  test(
    'closing retains the source and background service until native cancellation finishes',
    () async {
      final entered = Completer<void>();
      final finish = Completer<void>();
      encoder.onEncode = (request, token) async {
        entered.complete();
        await token.whenCancel;
        await finish.future;
        expect(await File(request.sourcePath).exists(), isTrue);
      };
      final service = GifConversionService(
        preparation: preparation,
        backend: encoder,
      );
      final source = await prepare(service);
      final background = _Background();
      final controller = GifEditorController(
        source: source,
        service: service,
        background: background,
      );
      final conversion = controller.create();
      await entered.future;
      expect(background.running, isTrue);
      controller.dispose();
      await source.release();
      expect(await File(source.lease.path).exists(), isTrue);
      expect(background.running, isTrue);
      finish.complete();
      await conversion;
      expect(background.running, isFalse);
      expect(
        await Directory('${root.path}/boorusama-share').list().toList(),
        isEmpty,
      );
    },
  );

  test(
    'cancel preserves selection and oversized retry reduces frames and dimensions',
    () async {
      encoder.onValidate = (request, _) async => _matchingEvidence(request);
      final service = GifConversionService(
        preparation: preparation,
        backend: encoder,
      );
      final source = await prepare(service);
      final controller = GifEditorController(source: source, service: service);
      controller.update(
        controller.selection
            .moveEnd(const Duration(seconds: 6))
            .moveWindow(const Duration(seconds: 5))
            .copyWith(speedPreset: .5),
      );
      final entered = Completer<void>();
      encoder.onEncode = (request, token) async {
        entered.complete();
        await token.whenCancel;
      };
      final first = controller.create();
      await entered.future;
      controller.cancel();
      await first;
      expect(controller.phase, GifEditorPhase.editing);
      expect(controller.selection.start, const Duration(seconds: 5));
      expect(controller.selection.speedPreset, .5);
      encoder.onEncode = (request, _) async {
        final output = await File(
          request.outputPath,
        ).open(mode: FileMode.write);
        await output.truncate(100000001);
        await output.close();
      };
      await controller.create();
      expect(controller.phase, GifEditorPhase.error);
      expect(controller.error!.failure, GifConversionFailure.oversized);
      encoder.onEncode = null;
      await controller.retrySmaller();
      expect(controller.phase, GifEditorPhase.preview);
      expect(controller.selection.start, const Duration(seconds: 5));
      expect(controller.selection.speedPreset, .5);
      expect(controller.selection.sourceFrameRate, 12);
      expect(controller.selection.resolution, GifResolution.px360);
      expect(encoder.request!.plan.width, 360);
      expect(downloads, 1);
      await controller.adjust();
      controller.dispose();
      await source.release();
    },
  );

  test(
    'lifecycle stub uses temporary video and releases it after validation',
    () async {
      encoder.onValidate = (request, _) async => _matchingEvidence(request);
      final progress = <GifConversionProgress>[];
      final lease = await convert(onProgress: progress.add);

      expect(lease.mimeType, 'image/gif');
      expect(lease.path, endsWith('.gif'));
      expect(encoder.request!.sourcePath, isNot(encoder.request!.outputPath));
      expect(encoder.request!.plan.start, const Duration(seconds: 26));
      expect(encoder.request!.plan.duration, const Duration(seconds: 4));
      expect(await File(encoder.request!.sourcePath).exists(), isFalse);
      expect(await File(lease.path).exists(), isTrue);
      expect(
        progress.map((p) => p.stage),
        containsAllInOrder([
          GifConversionStage.downloading,
          GifConversionStage.inspecting,
          GifConversionStage.encoding,
        ]),
      );

      await lease.release();
      expect(await File(lease.path).exists(), isFalse);
    },
  );

  test('a failed full decode report deletes the temporary GIF', () async {
    encoder.onValidate = (request, _) async => _matchingEvidence(
      request,
      fullDecodeSucceeded: false,
    );
    await expectLater(
      convert(),
      throwsA(
        isA<GifConversionException>().having(
          (e) => e.failure,
          'failure',
          GifConversionFailure.invalidOutput,
        ),
      ),
    );
    expect(await File(encoder.request!.outputPath).exists(), isFalse);
  });

  final invalidEvidenceCases =
      <({String name, GifOutputValidation Function(GifEncodeRequest) report})>[
        (
          name: 'wrong canvas width',
          report: (request) =>
              _matchingEvidence(request, canvasWidth: request.plan.width + 1),
        ),
        (
          name: 'wrong canvas height',
          report: (request) =>
              _matchingEvidence(request, canvasHeight: request.plan.height + 1),
        ),
        (
          name: 'mismatched frame canvases',
          report: (request) =>
              _matchingEvidence(request, allFramesMatchCanvas: false),
        ),
        (
          name: 'zero frames',
          report: (request) => _matchingEvidence(
            request,
            frameCount: 0,
            frameDelayCentiseconds: const [],
          ),
        ),
        (
          name: 'one frame for a four-second export',
          report: (request) => _matchingEvidence(
            request,
            frameCount: 1,
            frameDelayCentiseconds: const [8],
          ),
        ),
        (
          name: 'too few frames for requested cadence',
          report: (request) => _matchingEvidence(
            request,
            frameCount: 2,
            frameDelayCentiseconds: const [8, 9],
          ),
        ),
        (
          name: 'missing frame delay',
          report: (request) => _matchingEvidence(
            request,
            frameDelayCentiseconds: _matchingEvidence(
              request,
            ).frameDelayCentiseconds!.skip(1).toList(),
          ),
        ),
        (
          name: 'incorrect frame cadence',
          report: (request) => _matchingEvidence(
            request,
            frameDelayCentiseconds: [
              20,
              ..._matchingEvidence(request).frameDelayCentiseconds!.skip(1),
            ],
          ),
        ),
        (
          name: 'incorrect total duration',
          report: (request) => _matchingEvidence(
            request,
            frameDelayCentiseconds: List.filled(
              _matchingEvidence(request).frameCount!,
              9,
            ),
          ),
        ),
        (
          name: 'finite looping',
          report: (request) => _matchingEvidence(request, infiniteLoop: false),
        ),
        (
          name: 'missing loop extension',
          report: (request) => _matchingEvidence(request, infiniteLoop: null),
        ),
      ];

  for (final c in invalidEvidenceCases) {
    test('${c.name} cannot produce a GIF lease', () async {
      encoder.onValidate = (request, _) async => c.report(request);
      await expectLater(
        convert(),
        throwsA(
          isA<GifConversionException>().having(
            (e) => e.failure,
            'failure',
            GifConversionFailure.invalidOutput,
          ),
        ),
      );
      expect(await File(encoder.request!.outputPath).exists(), isFalse);
    });
  }

  test(
    'one missing frame at 1 FPS cannot shorten a six-second export',
    () async {
      encoder.metadata = const GifSourceMetadata(
        duration: Duration(seconds: 30),
        complete: true,
        width: 1920,
        height: 1080,
        rotationDegrees: 0,
        sampleAspectRatio: 1,
        frameRate: 1,
      );
      encoder.onValidate = (request, _) async => _matchingEvidence(
        request,
        frameCount: 5,
        frameDelayCentiseconds: const [100, 100, 100, 100, 100],
      );

      await expectLater(
        convert(
          settings: const GifExportSettings(
            start: Duration.zero,
            duration: Duration(seconds: 6),
            resolution: GifResolution.px480,
            frameRate: GifFrameRate.original,
          ),
        ),
        throwsA(
          isA<GifConversionException>().having(
            (e) => e.failure,
            'failure',
            GifConversionFailure.invalidOutput,
          ),
        ),
      );
    },
  );

  test(
    'one-frame evidence is invalid even when canvas, timing and loop match',
    () {
      const plan = GifExportPlan(
        start: Duration.zero,
        duration: Duration(seconds: 1),
        width: 480,
        height: 270,
        frameRate: 1,
        rotationDegrees: 0,
        sampleAspectRatio: 1,
      );
      const evidence = GifOutputValidation(
        fullDecodeSucceeded: true,
        canvasWidth: 480,
        canvasHeight: 270,
        allFramesMatchCanvas: true,
        frameCount: 1,
        frameDelayCentiseconds: [100],
        infiniteLoop: true,
      );

      expect(gifOutputMatchesPlan(evidence, plan), isFalse);
    },
  );

  test('two frames at 1 FPS can produce a stubbed animated lease', () async {
    encoder.metadata = const GifSourceMetadata(
      duration: Duration(seconds: 30),
      complete: true,
      width: 1920,
      height: 1080,
      rotationDegrees: 0,
      sampleAspectRatio: 1,
      frameRate: 1,
    );
    encoder.onValidate = (request, _) async => _matchingEvidence(request);

    final lease = await convert(
      settings: const GifExportSettings(
        start: Duration.zero,
        duration: Duration(seconds: 2),
        resolution: GifResolution.px480,
        frameRate: GifFrameRate.original,
      ),
    );
    expect(encoder.request!.plan.duration, const Duration(seconds: 2));
    await lease.release();
  });

  test('exactly 100 MB is accepted with matching stubbed evidence', () async {
    encoder.onEncode = (request, _) async {
      final output = await File(request.outputPath).open(mode: FileMode.write);
      await output.writeFrom(img.encodeGif(img.Image(width: 1, height: 1)));
      await output.truncate(100_000_000);
      await output.close();
    };
    encoder.onValidate = (request, _) async => _matchingEvidence(request);

    final lease = await convert();
    expect(await File(lease.path).length(), 100_000_000);
    await lease.release();
  });

  test('output growth during validation is rejected and deleted', () async {
    encoder.onValidate = (request, _) async {
      final output = await File(request.outputPath).open(mode: FileMode.append);
      await output.truncate(100_000_001);
      await output.close();
      return _matchingEvidence(request);
    };
    await expectLater(
      convert(),
      throwsA(
        isA<GifConversionException>().having(
          (e) => e.failure,
          'failure',
          GifConversionFailure.oversized,
        ),
      ),
    );
    expect(await File(encoder.request!.outputPath).exists(), isFalse);
  });

  test(
    'cancellation wins over a typed adapter failure and retains its cause',
    () async {
      final token = CancelToken();
      const original = GifConversionException(GifConversionFailure.encoder);
      encoder.onEncode = (_, cancelToken) {
        cancelToken.cancel();
        throw original;
      };
      await expectLater(
        convert(cancelToken: token),
        throwsA(
          isA<GifConversionException>()
              .having(
                (e) => e.failure,
                'failure',
                GifConversionFailure.cancelled,
              )
              .having((e) => e.cause, 'cause', same(original)),
        ),
      );
      expect(await File(encoder.request!.sourcePath).exists(), isFalse);
    },
  );

  test('missing native plugin preserves cause and reports its stage', () async {
    final original = MissingPluginException('Native FFmpeg plugin unavailable');
    encoder.onEncode = (_, _) => throw original;
    await expectLater(
      convert(),
      throwsA(
        isA<GifConversionException>()
            .having(
              (e) => e.failure,
              'failure',
              GifConversionFailure.encoderUnavailable,
            )
            .having((e) => e.stage, 'stage', GifConversionStage.encoding)
            .having((e) => e.cause, 'cause', same(original)),
      ),
    );
    expect(await File(encoder.request!.sourcePath).exists(), isFalse);
  });

  test('encoder failure removes partial GIF and temporary video', () async {
    encoder.onEncode = (request, _) async {
      await File(request.outputPath).writeAsBytes([1, 2, 3]);
      throw StateError('encoder failed');
    };

    await expectLater(
      convert(),
      throwsA(
        isA<GifConversionException>().having(
          (e) => e.failure,
          'failure',
          GifConversionFailure.encoder,
        ),
      ),
    );
    expect(await File(encoder.request!.outputPath).exists(), isFalse);
    expect(await File(encoder.request!.sourcePath).exists(), isFalse);
  });

  test(
    'failed output deletion still releases the source and keeps encoder failure',
    () async {
      encoder.onEncode = (request, _) async {
        await File(request.outputPath).writeAsBytes([1, 2, 3]);
        throw StateError('encoder failed');
      };
      var deletionAttempts = 0;
      final service = GifConversionService(
        preparation: preparation,
        backend: encoder,
        deletePartialOutput: (_) {
          deletionAttempts++;
          return Future<void>.error(const FileSystemException('output locked'));
        },
      );

      await expectLater(
        service.convert(
          sourceUrl: 'http://127.0.0.1:${server.port}/post.mp4',
          headers: const {},
        ),
        throwsA(
          isA<GifConversionException>()
              .having((e) => e.failure, 'failure', GifConversionFailure.encoder)
              .having((e) => e.cleanupErrors.length, 'cleanup errors', 1),
        ),
      );
      expect(deletionAttempts, 1);
      expect(await File(encoder.request!.sourcePath).exists(), isFalse);
    },
  );

  test(
    'failed source release still deletes partial output and keeps cancellation',
    () async {
      final token = CancelToken();
      encoder.onEncode = (request, cancelToken) async {
        await File(request.outputPath).writeAsBytes([1, 2, 3]);
        cancelToken.cancel();
      };
      var releaseAttempts = 0;
      final service = GifConversionService(
        preparation: preparation,
        backend: encoder,
        releaseSource: (lease) {
          releaseAttempts++;
          return Future<void>.error(const FileSystemException('source locked'));
        },
      );

      await expectLater(
        service.convert(
          sourceUrl: 'http://127.0.0.1:${server.port}/post.mp4',
          headers: const {},
          cancelToken: token,
        ),
        throwsA(
          isA<GifConversionException>()
              .having(
                (e) => e.failure,
                'failure',
                GifConversionFailure.cancelled,
              )
              .having((e) => e.cleanupErrors.length, 'cleanup errors', 1),
        ),
      );
      expect(releaseAttempts, 1);
      expect(await File(encoder.request!.outputPath).exists(), isFalse);
    },
  );

  test(
    'both cleanup failures are reported without replacing the size failure',
    () async {
      encoder.onEncode = (request, _) async {
        final output = await File(
          request.outputPath,
        ).open(mode: FileMode.write);
        await output.truncate(100_000_001);
        await output.close();
      };
      var deletionAttempts = 0;
      var releaseAttempts = 0;
      final service = GifConversionService(
        preparation: preparation,
        backend: encoder,
        deletePartialOutput: (_) {
          deletionAttempts++;
          return Future<void>.error(const FileSystemException('output locked'));
        },
        releaseSource: (_) {
          releaseAttempts++;
          return Future<void>.error(const FileSystemException('source locked'));
        },
      );

      await expectLater(
        service.convert(
          sourceUrl: 'http://127.0.0.1:${server.port}/post.mp4',
          headers: const {},
        ),
        throwsA(
          isA<GifConversionException>()
              .having(
                (e) => e.failure,
                'failure',
                GifConversionFailure.oversized,
              )
              .having((e) => e.cleanupErrors.length, 'cleanup errors', 2),
        ),
      );
      expect((deletionAttempts, releaseAttempts), (1, 1));
    },
  );

  test('cancellation during encoding removes partial GIF and source', () async {
    final token = CancelToken();
    encoder.onEncode = (request, cancelToken) async {
      await File(request.outputPath).writeAsBytes([1, 2, 3]);
      cancelToken.cancel();
    };

    await expectLater(
      convert(cancelToken: token),
      throwsA(
        isA<GifConversionException>().having(
          (e) => e.failure,
          'failure',
          GifConversionFailure.cancelled,
        ),
      ),
    );
    expect(await File(encoder.request!.outputPath).exists(), isFalse);
    expect(await File(encoder.request!.sourcePath).exists(), isFalse);
  });

  test(
    'cancellation during output validation takes precedence over invalid output',
    () async {
      final validating = Completer<void>();
      final finishValidation = Completer<void>();
      final token = CancelToken();
      encoder.onValidate = (_, _) async {
        validating.complete();
        await finishValidation.future;
        return _matchingEvidence(encoder.request!, fullDecodeSucceeded: false);
      };

      final outcome = expectLater(
        convert(cancelToken: token),
        throwsA(
          isA<GifConversionException>().having(
            (e) => e.failure,
            'failure',
            GifConversionFailure.cancelled,
          ),
        ),
      );
      await validating.future;
      token.cancel();
      finishValidation.complete();
      await outcome;

      expect(await File(encoder.request!.outputPath).exists(), isFalse);
      expect(await File(encoder.request!.sourcePath).exists(), isFalse);
    },
  );

  test(
    'cancellation while releasing the source never returns a GIF lease',
    () async {
      encoder.onValidate = (request, _) async => _matchingEvidence(request);
      final releasing = Completer<void>();
      final finishRelease = Completer<void>();
      final token = CancelToken();
      final service = GifConversionService(
        preparation: preparation,
        backend: encoder,
        releaseSource: (lease) async {
          releasing.complete();
          await finishRelease.future;
          await lease.release();
        },
      );

      final outcome = expectLater(
        service.convert(
          sourceUrl: 'http://127.0.0.1:${server.port}/post.mp4',
          headers: const {},
          cancelToken: token,
        ),
        throwsA(
          isA<GifConversionException>().having(
            (e) => e.failure,
            'failure',
            GifConversionFailure.cancelled,
          ),
        ),
      );
      await releasing.future;
      token.cancel();
      finishRelease.complete();
      await outcome;

      expect(await File(encoder.request!.outputPath).exists(), isFalse);
      expect(await File(encoder.request!.sourcePath).exists(), isFalse);
    },
  );

  test('output above 100 MB is rejected and deleted', () async {
    encoder.onEncode = (request, _) async {
      final output = await File(request.outputPath).open(mode: FileMode.write);
      await output.truncate(100_000_001);
      await output.close();
    };

    await expectLater(
      convert(),
      throwsA(
        isA<GifConversionException>().having(
          (e) => e.failure,
          'failure',
          GifConversionFailure.oversized,
        ),
      ),
    );
    expect(await File(encoder.request!.outputPath).exists(), isFalse);
  });

  test(
    'a non-GIF header is rejected before backend validation',
    () async {
      encoder.onValidate = (request, _) async => _matchingEvidence(request);
      encoder.onEncode = (request, _) async {
        await File(request.outputPath).writeAsBytes([1, 2, 3, 4, 5, 6, 7]);
      };

      await expectLater(
        convert(),
        throwsA(
          isA<GifConversionException>().having(
            (e) => e.failure,
            'failure',
            GifConversionFailure.invalidOutput,
          ),
        ),
      );
      expect(await File(encoder.request!.outputPath).exists(), isFalse);
    },
  );

  test('unavailable backend rejects conversion before downloading', () async {
    final service = GifConversionService(preparation: preparation);

    await expectLater(
      service.convert(
        sourceUrl: 'http://127.0.0.1:${server.port}/post.mp4',
        headers: const {},
      ),
      throwsA(
        isA<GifConversionException>().having(
          (e) => e.failure,
          'failure',
          GifConversionFailure.encoderUnavailable,
        ),
      ),
    );
    expect(
      await Directory('${root.path}/boorusama-share').exists(),
      isFalse,
    );
  });
}

class _FakeGifEncoder implements GifEncoderBackend {
  var metadata = const GifSourceMetadata(
    duration: Duration(seconds: 30),
    complete: true,
    width: 1920,
    height: 1080,
    rotationDegrees: 0,
    sampleAspectRatio: 1,
    frameRate: 24,
  );
  GifEncodeRequest? request;
  var inspections = 0;
  Future<void> Function(GifEncodeRequest, CancelToken)? onEncode;
  Future<GifOutputValidation> Function(GifEncodeRequest, CancelToken)?
  onValidate;

  @override
  Future<GifSourceMetadata> inspect(
    String sourcePath, {
    required CancelToken cancelToken,
  }) async {
    inspections++;
    return metadata;
  }

  @override
  Future<void> encode(
    GifEncodeRequest request, {
    required CancelToken cancelToken,
    void Function(double? fraction)? onProgress,
  }) async {
    this.request = request;
    if (onEncode case final action?) return action(request, cancelToken);
    final gifBytes = img.encodeGif(img.Image(width: 1, height: 1));
    await File(request.outputPath).writeAsBytes(gifBytes);
    onProgress?.call(1);
  }

  @override
  Future<GifOutputValidation> validateOutput(
    GifEncodeRequest request, {
    required CancelToken cancelToken,
  }) async {
    if (onValidate case final action?) return action(request, cancelToken);
    return _matchingEvidence(request, fullDecodeSucceeded: false);
  }
}

class _Background extends GifBackgroundExecution {
  _Background() : super(title: 'Creating GIF', cancelLabel: 'Cancel');
  var running = false;
  @override
  Future<void> start(CancelToken token) async {
    running = true;
  }

  @override
  Future<void> stop() async {
    running = false;
  }
}

GifOutputValidation _matchingEvidence(
  GifEncodeRequest request, {
  bool fullDecodeSucceeded = true,
  int? canvasWidth,
  int? canvasHeight,
  bool allFramesMatchCanvas = true,
  int? frameCount,
  List<int>? frameDelayCentiseconds,
  bool? infiniteLoop = true,
}) {
  final plan = request.plan;
  final count =
      (plan.duration.inMicroseconds *
              plan.encodedSourceFrameRate /
              Duration.microsecondsPerSecond)
          .ceil();
  final idealDelay = 100 / plan.encodedPlaybackFrameRate;
  final delays = List<int>.generate(
    count,
    (index) =>
        ((index + 1) * idealDelay).round() - (index * idealDelay).round(),
  );
  return GifOutputValidation(
    fullDecodeSucceeded: fullDecodeSucceeded,
    canvasWidth: canvasWidth ?? plan.width,
    canvasHeight: canvasHeight ?? plan.height,
    allFramesMatchCanvas: allFramesMatchCanvas,
    frameCount: frameCount ?? count,
    frameDelayCentiseconds: frameDelayCentiseconds ?? delays,
    infiniteLoop: infiniteLoop,
  );
}
