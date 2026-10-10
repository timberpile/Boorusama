import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'gif_conversion_service.dart';
import 'gif_editor_selection.dart';
import 'gif_loop_refinement.dart';

abstract interface class GifLoopRefiner {
  Future<GifLoopResult> refine({
    required GifPreparedSource source,
    required GifEditorSelection selection,
    required CancelToken cancelToken,
  });
}

/// Optional runner capability: logs and raw frame bytes belong to the SAME
/// FFmpeg session. A separate FFprobe frame scan cannot establish that pairing.
abstract interface class GifLoopCommandRunner {
  Future<String> runWithOutput(List<String> arguments, CancelToken token);
}

abstract interface class GifLoopFrameDecoder {
  Future<GifLoopFrames> decode(String sourcePath, GifLoopRequest request, CancelToken token);
}

GifLoopRequest gifLoopRequest(GifEditorSelection selection) => GifLoopRequest(
  start: selection.start.inMicroseconds,
  end: selection.end.inMicroseconds,
  sourceDuration: selection.sourceDuration.inMicroseconds,
  minimumDuration: math.max(
    GifEditorSelection.minimumWindow.inMicroseconds,
    (2000000 / selection.sourceFrameRate).ceil(),
  ),
);

class GifLoopRefinementService implements GifLoopRefiner {
  const GifLoopRefinementService(this.decoder);
  final GifLoopFrameDecoder decoder;

  @override
  Future<GifLoopResult> refine({
    required GifPreparedSource source,
    required GifEditorSelection selection,
    required CancelToken cancelToken,
  }) async {
    final request = gifLoopRequest(selection);
    if (cancelToken.isCancelled) {
      return const GifLoopResult.noMatch(GifLoopNoMatchReason.cancelled);
    }
    if (!request.isValid || request.isFullSource || !selection.canCreate) {
      return const GifLoopResult.noMatch();
    }
    // Retain independently of the editor route. The decoder does not return
    // from cancellation until native writers have stopped and cleanup is done.
    source.lease.retain();
    try {
      final frames = await decoder.decode(source.lease.path, request, cancelToken);
      if (cancelToken.isCancelled) {
        return const GifLoopResult.noMatch(GifLoopNoMatchReason.cancelled);
      }
      return await _compareInIsolate(frames, request, cancelToken);
    } on GifLoopBudgetException {
      return GifLoopResult.noMatch(cancelToken.isCancelled
          ? GifLoopNoMatchReason.cancelled : GifLoopNoMatchReason.budget);
    } on FormatException {
      return GifLoopResult.noMatch(cancelToken.isCancelled
          ? GifLoopNoMatchReason.cancelled : GifLoopNoMatchReason.invalidFrames);
    } catch (_) {
      // Keep source paths, FFmpeg logs and any source metadata out of feedback.
      return GifLoopResult.noMatch(cancelToken.isCancelled
          ? GifLoopNoMatchReason.cancelled : GifLoopNoMatchReason.unavailable);
    } finally {
      await source.lease.release();
    }
  }
}

class GifLoopBudgetException implements Exception {}

class FfmpegGifLoopDecoder implements GifLoopFrameDecoder {
  const FfmpegGifLoopDecoder(this.runner);
  final GifLoopCommandRunner runner;

  @override
  Future<GifLoopFrames> decode(
    String sourcePath, GifLoopRequest request, CancelToken token,
  ) async {
    if (token.isCancelled) throw const FormatException('Analysis cancelled');
    final directory = await File(sourcePath).parent.createTemp('gif-loop-');
    final output = File('${directory.path}/frames.gray');
    final nativeToken = CancelToken();
    var active = true;
    var timedOut = false;
    // Cancellation requests stop only this session, never unrelated encoding.
    unawaited(token.whenCancel.then((_) {
      if (active) nativeToken.cancel();
    }));
    final deadline = Timer(const Duration(seconds: 30), () {
      timedOut = true;
      nativeToken.cancel();
    });
    try {
      if (token.isCancelled) nativeToken.cancel();
      final log = await runner.runWithOutput(
        gifLoopDecodeArguments(sourcePath, output.path, request), nativeToken,
      );
      if (timedOut) throw GifLoopBudgetException();
      if (token.isCancelled) throw const FormatException('Analysis cancelled');
      final length = await output.length();
      if (length > 4500 * 4096) throw GifLoopBudgetException();
      return gifLoopFramesFromOutput(await output.readAsBytes(), log);
    } catch (_) {
      if (timedOut && !token.isCancelled) throw GifLoopBudgetException();
      rethrow;
    } finally {
      active = false;
      deadline.cancel();
      // The runner contract guarantees native completion before returning.
      // A timeout must not delete a file underneath a still-running decoder.
      await directory.delete(recursive: true);
    }
  }
}

List<String> gifLoopDecodeArguments(
  String sourcePath, String outputPath, GifLoopRequest request,
) => [
  '-y', '-hide_banner', '-nostdin', '-loglevel', 'info', '-xerror',
  '-threads', '1', '-copyts', '-start_at_zero',
  '-ss', (request.decodeStart / 1000000).toStringAsFixed(6),
  '-t', ((request.decodeEnd - request.decodeStart) / 1000000).toStringAsFixed(6),
  '-i', sourcePath, '-map', '0:v:0', '-an', '-sn', '-dn',
  '-vf', 'scale=64:64:flags=area,format=gray,showinfo=checksum=0',
  '-fps_mode', 'passthrough', '-frames:v', '4501',
  '-threads', '1', '-f', 'rawvideo', '-pix_fmt', 'gray', outputPath,
];

/// Read integer PTS plus its rational time base, NOT rounded pts_time text.
/// copyts/start_at_zero preserves the normalized source clock through seeking.
GifLoopFrames gifLoopFramesFromOutput(Uint8List bytes, String log) {
  if (bytes.isEmpty || bytes.length % 4096 != 0) {
    throw const FormatException('Incomplete analysis frames');
  }
  final count = bytes.length ~/ 4096;
  if (count > 4500) throw GifLoopBudgetException();
  final timeBases = RegExp(r'config in time_base:\s*(\d+)/(\d+)')
      .allMatches(log).toList();
  if (timeBases.length != 1) {
    throw const FormatException('Missing or changing frame time base');
  }
  final numerator = int.parse(timeBases.single.group(1)!);
  final denominator = int.parse(timeBases.single.group(2)!);
  if (numerator <= 0 || denominator <= 0) {
    throw const FormatException('Invalid frame time base');
  }
  final records = RegExp(r'\bn:\s*(\d+)\s+pts:\s*(-?\d+)\s+pts_time:')
      .allMatches(log).toList();
  if (records.length != count) {
    throw const FormatException('Frame/PTS count mismatch');
  }
  final pts = <int>[];
  for (var i = 0; i < records.length; i++) {
    if (int.parse(records[i].group(1)!) != i) {
      throw const FormatException('Frame order mismatch');
    }
    final ticks = int.parse(records[i].group(2)!);
    final timestamp = (ticks * numerator * 1000000 + denominator ~/ 2) ~/ denominator;
    if (ticks < 0 || (pts.isNotEmpty && timestamp <= pts.last)) {
      throw const FormatException('Invalid/non-monotonic frame PTS');
    }
    pts.add(timestamp);
  }
  return GifLoopFrames(pixels: bytes, timestamps: pts);
}

Future<GifLoopResult> _compareInIsolate(
  GifLoopFrames frames, GifLoopRequest request, CancelToken token,
) async {
  final port = ReceivePort();
  final completed = Completer<GifLoopResult>();
  Isolate? worker;
  void finish(GifLoopResult result) {
    if (!completed.isCompleted) completed.complete(result);
  }
  final subscription = port.listen((dynamic message) {
    finish(message is GifLoopResult ? message
        : const GifLoopResult.noMatch(GifLoopNoMatchReason.unavailable));
  });
  final deadline = Timer(const Duration(seconds: 10), () {
    finish(const GifLoopResult.noMatch(GifLoopNoMatchReason.budget));
  });
  unawaited(token.whenCancel.then((_) {
    finish(const GifLoopResult.noMatch(GifLoopNoMatchReason.cancelled));
  }));
  try {
    if (token.isCancelled) return const GifLoopResult.noMatch(GifLoopNoMatchReason.cancelled);
    worker = await Isolate.spawn(
      _compareWorker, (port.sendPort, frames, request),
      onError: port.sendPort, onExit: port.sendPort,
    );
    return await completed.future;
  } finally {
    // No native resources live in this worker, so immediate cancellation is safe.
    worker?.kill(priority: Isolate.immediate);
    deadline.cancel();
    await subscription.cancel();
    port.close();
  }
}

void _compareWorker((SendPort, GifLoopFrames, GifLoopRequest) input) {
  final (reply, frames, request) = input;
  reply.send(refineGifLoop(frames, request));
}
