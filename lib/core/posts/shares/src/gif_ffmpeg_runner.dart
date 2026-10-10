import 'dart:async';

import 'package:dio/dio.dart';
import 'package:ffmpeg_kit_flutter_new_min/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_min/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new_min/return_code.dart';
import 'package:ffmpeg_kit_flutter_new_min/session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../../../foundation/platform.dart';
import 'gif_export_contract.dart';
import 'gif_ffmpeg_backend.dart';
import 'gif_loop_refinement_service.dart';

final gifEncoderBackendProvider = Provider<GifEncoderBackend?>(
  (ref) => isAndroid()
      ? const FfmpegGifBackend(
          FfmpegKitGifRunner(),
          rotationReader: readAndroidGifRotation,
        )
      : null,
);

final gifLoopRefinerProvider = Provider<GifLoopRefiner?>(
  (ref) => isAndroid()
      ? const GifLoopRefinementService(FfmpegGifLoopDecoder(FfmpegKitGifRunner()))
      : null,
);

Future<int?> readAndroidGifRotation(String path) async {
  final clockwise = await const MethodChannel(
    'boorusama/gif_metadata',
  ).invokeMethod<int>('rotation', {'path': path});
  // Match FFprobe's counterclockwise display-matrix convention.
  return clockwise == null ? null : ((-clockwise % 360) + 360) % 360;
}

class FfmpegKitGifRunner implements GifCommandRunner, GifLoopCommandRunner {
  const FfmpegKitGifRunner();

  @override
  Future<String> probe(List<String> arguments, CancelToken token) async {
    final session = await _execute(
      (complete) => FFprobeKit.executeWithArgumentsAsync(
        arguments,
        (session) => complete(session),
        (_) {},
      ),
      token,
    );
    return await session.getOutput() ?? '';
  }

  @override
  Future<void> run(
    List<String> arguments,
    CancelToken token, {
    void Function(int)? onTime,
  }) async {
    await _execute(
      (complete) => FFmpegKit.executeWithArgumentsAsync(
        arguments,
        (session) => complete(session),
        (_) {},
        (statistics) => onTime?.call(statistics.getTime()),
      ),
      token,
    );
  }

  @override
  Future<String> runWithOutput(List<String> arguments, CancelToken token) async {
    final session = await _execute(
      (complete) => FFmpegKit.executeWithArgumentsAsync(
        arguments, (session) => complete(session), (_) {},
      ),
      token,
    );
    return await session.getOutput() ?? '';
  }

  Future<Session> _execute(
    Future<Session> Function(void Function(Session)) start,
    CancelToken token,
  ) async {
    if (token.isCancelled) {
      throw const GifConversionException(GifConversionFailure.cancelled);
    }
    final completed = Completer<Session>();
    final session = await start((session) {
      if (!completed.isCompleted) completed.complete(session);
    });
    var finished = false;
    Object? cancellationError;
    // Wait for the native completion callback even after requesting cancel:
    // deleting the partial file earlier would race native writers.
    Future<void> cancel() async {
      try {
        await session.cancel();
      } catch (error) {
        cancellationError = error;
      }
    }

    unawaited(
      token.whenCancel.then((_) async {
        if (!finished) await cancel();
      }),
    );
    try {
      if (token.isCancelled) await cancel();
      final result = await completed.future;
      final code = await result.getReturnCode();
      if (token.isCancelled || ReturnCode.isCancel(code)) {
        throw GifConversionException(
          GifConversionFailure.cancelled,
          cause: cancellationError,
        );
      }
      if (!ReturnCode.isSuccess(code)) {
        throw const GifConversionException(GifConversionFailure.encoder);
      }
      return result;
    } finally {
      finished = true;
    }
  }
}
