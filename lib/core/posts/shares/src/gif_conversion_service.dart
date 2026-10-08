// ignore_for_file: avoid_slow_async_io
import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import 'gif_export_contract.dart';
import 'share_media_preparation.dart';
import 'share_resolution_control.dart';

class GifPreparedSource {
  const GifPreparedSource({
    required this.lease,
    required this.metadata,
    this.timeline,
  });
  final ShareMediaLease lease;
  final GifSourceMetadata metadata;
  final ShareMediaLease? timeline;
  Future<void> release() async {
    try {
      await lease.release();
    } finally {
      await timeline?.release();
    }
  }
}

class GifConversionService {
  GifConversionService({
    required this.preparation,
    this.backend,
    Future<void> Function(File)? deletePartialOutput,
    Future<void> Function(ShareMediaLease)? releaseSource,
  }) : deletePartialOutput = deletePartialOutput ?? _deletePartialOutput,
       releaseSource = releaseSource ?? _releaseSource;

  final ShareMediaPreparation preparation;
  final GifEncoderBackend? backend;
  final Future<void> Function(File) deletePartialOutput;
  final Future<void> Function(ShareMediaLease) releaseSource;

  Future<GifPreparedSource> prepareSource({
    required String sourceUrl,
    required Map<String, String> headers,
    required CancelToken cancelToken,
    void Function(GifConversionProgress)? onProgress,
  }) async {
    final encoder = backend;
    if (encoder == null) {
      throw const GifConversionException(
        GifConversionFailure.encoderUnavailable,
      );
    }
    ShareMediaLease? source;
    ShareMediaLease? timeline;
    var stage = GifConversionStage.downloading;
    try {
      source = await preparation.prepare(
        url: sourceUrl,
        fallbackExtension: null,
        kind: ShareMediaKind.video,
        headers: headers,
        cancelToken: cancelToken,
        onProgress: (value) =>
            onProgress?.call(GifConversionProgress(stage, value)),
      );
      stage = GifConversionStage.inspecting;
      onProgress?.call(GifConversionProgress(stage, null));
      final metadata = await encoder.inspect(
        source.path,
        cancelToken: cancelToken,
      );
      GifExportPlan.fromSource(
        metadata,
        mimeType: source.mimeType,
        settings: GifExportSettings(
          start: Duration.zero,
          duration: metadata.duration ?? Duration.zero,
          resolution: GifResolution.original,
          frameRate: GifFrameRate.original,
        ),
      );
      if (encoder is GifTimelineBackend) {
        timeline = ShareMediaLease(
          path: '${source.path}_timeline.png',
          mimeType: 'image/png',
        );
        try {
          await (encoder as GifTimelineBackend).createTimeline(
            sourcePath: source.path,
            outputPath: timeline.path,
            duration: metadata.duration!,
            cancelToken: cancelToken,
          );
        } catch (_) {
          await timeline.release();
          timeline = null;
        }
      }
      checkShareCancellation(cancelToken);
      return GifPreparedSource(
        lease: source,
        metadata: metadata,
        timeline: timeline,
      );
    } catch (error, stack) {
      final cleanupErrors = <Object>[];
      for (final lease in [source, timeline]) {
        try {
          await lease?.release();
        } catch (failure) {
          cleanupErrors.add(failure);
        }
      }
      final failure = _mapFailure(error, cancelToken);
      Error.throwWithStackTrace(
        GifConversionException(
          failure.failure,
          cause: failure.cause,
          stage: stage,
          cleanupErrors: cleanupErrors,
        ),
        stack,
      );
    }
  }

  Future<ShareMediaLease> convertPrepared({
    required GifPreparedSource source,
    required GifExportSettings settings,
    required CancelToken cancelToken,
    void Function(GifConversionProgress)? onProgress,
  }) => convert(
    sourceUrl: '',
    headers: const {},
    settings: settings,
    cancelToken: cancelToken,
    onProgress: onProgress,
    preparedSource: source,
  );

  Future<ShareMediaLease> convert({
    required String sourceUrl,
    required Map<String, String> headers,
    GifExportSettings? settings,
    GifPreparedSource? preparedSource,
    Duration? playbackPosition,
    CancelToken? cancelToken,
    void Function(GifConversionProgress)? onProgress,
  }) async {
    final encoder = backend;
    if (encoder == null) {
      throw const GifConversionException(
        GifConversionFailure.encoderUnavailable,
      );
    }
    final token = cancelToken ?? CancelToken();
    var stage = GifConversionStage.downloading;
    ShareMediaLease? source;
    File? output;
    ShareMediaLease? result;
    GifConversionException? primaryFailure;
    StackTrace? primaryStack;
    try {
      checkShareCancellation(token);
      GifSourceMetadata metadata;
      if (preparedSource != null) {
        preparedSource.lease.retain();
        source = preparedSource.lease;
        metadata = preparedSource.metadata;
      } else {
        onProgress?.call(
          const GifConversionProgress(GifConversionStage.downloading, null),
        );
        source = await preparation.prepare(
          url: sourceUrl,
          kind: ShareMediaKind.video,
          fallbackExtension: null,
          headers: headers,
          cancelToken: token,
          onProgress: (fraction) => onProgress?.call(
            GifConversionProgress(
              GifConversionStage.downloading,
              fraction >= 0 ? fraction.clamp(0, 1) : null,
            ),
          ),
        );
        checkShareCancellation(token);
        onProgress?.call(
          const GifConversionProgress(GifConversionStage.inspecting, null),
        );
        stage = GifConversionStage.inspecting;
        metadata = await encoder.inspect(
          source.path,
          cancelToken: token,
        );
      }
      checkShareCancellation(token);
      final plan = GifExportPlan.fromSource(
        metadata,
        mimeType: source.mimeType,
        settings: settings,
        playbackPosition: playbackPosition,
      );
      final random = Random.secure();
      output = File(
        p.join(
          p.dirname(source.path),
          'boorusama_share_${DateTime.now().microsecondsSinceEpoch}_${random.nextInt(1 << 32)}.gif',
        ),
      );
      onProgress?.call(
        const GifConversionProgress(GifConversionStage.encoding, null),
      );
      final request = GifEncodeRequest(
        sourcePath: source.path,
        outputPath: output.path,
        plan: plan,
      );
      stage = GifConversionStage.encoding;
      await encoder.encode(
        request,
        cancelToken: token,
        onProgress: (fraction) => onProgress?.call(
          GifConversionProgress(
            GifConversionStage.encoding,
            switch (fraction) {
              final value? when value.isFinite => value.clamp(0, 1),
              _ => null,
            },
          ),
        ),
      );
      checkShareCancellation(token);
      if (!await output.exists()) {
        throw const GifConversionException(GifConversionFailure.invalidOutput);
      }
      final length = await output.length();
      if (length == 0) {
        throw const GifConversionException(GifConversionFailure.invalidOutput);
      }
      if (length > GifExportPlan.maxOutputBytes) {
        throw const GifConversionException(GifConversionFailure.oversized);
      }
      final handle = await output.open();
      try {
        final header = await handle.read(6);
        if (String.fromCharCodes(header) != 'GIF87a' &&
            String.fromCharCodes(header) != 'GIF89a') {
          throw const GifConversionException(
            GifConversionFailure.invalidOutput,
          );
        }
      } finally {
        await handle.close();
      }
      checkShareCancellation(token);
      stage = GifConversionStage.checking;
      onProgress?.call(GifConversionProgress(stage, null));
      GifOutputValidation validation;
      try {
        validation = await encoder.validateOutput(request, cancelToken: token);
      } catch (_) {
        checkShareCancellation(token);
        throw const GifConversionException(GifConversionFailure.invalidOutput);
      }
      checkShareCancellation(token);
      if (!gifOutputMatchesPlan(validation, plan)) {
        throw const GifConversionException(GifConversionFailure.invalidOutput);
      }
      checkShareCancellation(token);
      result = ShareMediaLease(path: output.path, mimeType: 'image/gif');
    } catch (error, stack) {
      primaryFailure = _mapFailure(error, token);
      primaryStack = stack;
    }

    final cleanupErrors = <Object>[];
    if (result == null && output != null) {
      try {
        await deletePartialOutput(output);
      } catch (error) {
        cleanupErrors.add(error);
      }
    }
    if (source != null) {
      try {
        await releaseSource(source);
      } catch (error) {
        cleanupErrors.add(error);
      }
    }
    if (result != null &&
        output != null &&
        (cleanupErrors.isNotEmpty || token.isCancelled)) {
      try {
        await deletePartialOutput(output);
      } catch (error) {
        cleanupErrors.add(error);
      }
    }
    if (result != null && token.isCancelled) {
      primaryFailure = const GifConversionException(
        GifConversionFailure.cancelled,
      );
      primaryStack = StackTrace.current;
    }

    if (result != null && primaryFailure == null && cleanupErrors.isEmpty) {
      try {
        checkShareCancellation(token);
        final finalStat = await output!.stat();
        checkShareCancellation(token);
        if (finalStat.type != FileSystemEntityType.file ||
            finalStat.size == 0) {
          throw const GifConversionException(
            GifConversionFailure.invalidOutput,
          );
        }
        if (finalStat.size > GifExportPlan.maxOutputBytes) {
          throw const GifConversionException(GifConversionFailure.oversized);
        }
      } catch (error, stack) {
        primaryFailure = _mapFailure(error, token);
        primaryStack = stack;
        try {
          await deletePartialOutput(output!);
        } catch (cleanupError) {
          cleanupErrors.add(cleanupError);
        }
      }
    }

    if (primaryFailure != null) {
      Error.throwWithStackTrace(
        GifConversionException(
          primaryFailure.failure,
          cleanupErrors: List.unmodifiable(cleanupErrors),
          cause: primaryFailure.cause,
          stage: primaryFailure.stage ?? stage,
        ),
        primaryStack!,
      );
    }
    if (cleanupErrors.isNotEmpty) {
      throw GifConversionException(
        GifConversionFailure.storage,
        cleanupErrors: List.unmodifiable(cleanupErrors),
      );
    }
    return result!;
  }
}

bool gifOutputMatchesPlan(GifOutputValidation validation, GifExportPlan plan) {
  if (!validation.fullDecodeSucceeded ||
      validation.canvasWidth != plan.width ||
      validation.canvasHeight != plan.height ||
      !validation.allFramesMatchCanvas ||
      validation.infiniteLoop != true) {
    return false;
  }

  final count = validation.frameCount;
  final delays = validation.frameDelayCentiseconds;
  if (count == null || count < 2 || delays == null || delays.length != count) {
    return false;
  }

  final expectedCount =
      (plan.duration.inMicroseconds *
              plan.encodedSourceFrameRate /
              Duration.microsecondsPerSecond)
          .ceil();
  if ((count - expectedCount).abs() > 1) {
    return false;
  }

  final idealDelayCentiseconds = 100 / plan.encodedPlaybackFrameRate;
  final minDelay = max(1, idealDelayCentiseconds.floor());
  final maxDelay = max(1, idealDelayCentiseconds.ceil());
  var totalCentiseconds = 0;
  for (final delay in delays) {
    if (delay < minDelay || delay > maxDelay) return false;
    totalCentiseconds += delay;
  }

  final expectedCentiseconds =
      plan.outputDuration.inMicroseconds /
      Duration.microsecondsPerMillisecond /
      10;
  // Allow half a centisecond of rounding per frame, plus one centisecond,
  // capped at 25 centiseconds for long or low-frame-rate exports.
  final durationToleranceCentiseconds = min(25, count * 0.5 + 1);
  return (totalCentiseconds - expectedCentiseconds).abs() <=
      durationToleranceCentiseconds;
}

GifConversionException _mapFailure(Object error, CancelToken token) =>
    switch (error) {
      _ when token.isCancelled => GifConversionException(
        GifConversionFailure.cancelled,
        cause: error,
      ),
      GifConversionException() => error,
      ShareMediaException() => GifConversionException(switch (error.failure) {
        ShareMediaFailure.cancelled => GifConversionFailure.cancelled,
        ShareMediaFailure.authentication => GifConversionFailure.authentication,
        ShareMediaFailure.storage => GifConversionFailure.storage,
        ShareMediaFailure.network => GifConversionFailure.network,
        _ => GifConversionFailure.unsupportedSource,
      }),
      FileSystemException() => const GifConversionException(
        GifConversionFailure.storage,
      ),
      MissingPluginException() => GifConversionException(
        GifConversionFailure.encoderUnavailable,
        cause: error,
      ),
      _ => GifConversionException(GifConversionFailure.encoder, cause: error),
    };

Future<void> _deletePartialOutput(File file) async {
  if (await file.exists()) await file.delete();
}

Future<void> _releaseSource(ShareMediaLease lease) => lease.release();
