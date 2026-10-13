import 'dart:async';
import 'dart:ui' as ui;

import 'package:boorusama/core/posts/shares/src/gif_conversion_service.dart';
import 'package:boorusama/core/posts/shares/src/gif_loop_buffer.dart';
import 'package:boorusama/core/posts/shares/src/gif_loop_frame_clock.dart';
import 'package:boorusama/core/posts/shares/src/gif_loop_preview_controller.dart';
import 'package:boorusama/core/posts/shares/src/gif_loop_refinement_service.dart';
import 'package:boorusama/core/posts/shares/src/gif_smooth_loop_backend.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

void main() {
  testWidgets(
    'adopted image buffer seeks, pauses and loops without native seeks',
    (tester) async {
      final images = await tester.runAsync(_images);
      final decoder = _Decoder();
      final native = _Native();
      final backend = GifSmoothLoopBackend(
        native: native,
        source: _Source(),
        decoder: decoder,
        onPosition: (_) {},
      );
      final controller = GifLoopPreviewController(
        backend: backend,
        start: const Duration(seconds: 1),
        end: const Duration(milliseconds: 1100),
        speed: 1,
        enabled: true,
      );
      backend.serialize = controller.synchronize;
      await controller.initialize();
      await tester.pump(const Duration(milliseconds: 400));
      decoder.result.complete(
        GifLoopBuffer(
          images!,
          const Duration(seconds: 1),
          GifLoopFrameClock([0, 50000], 100000),
        ),
      );
      await tester.pump();
      expect(backend.buffered, isTrue);
      expect(native.playing, isFalse);
      final nativeSeeks = native.seeks;
      await controller.seekTo(const Duration(milliseconds: 1075));
      expect(backend.frame.value, same(images[1]));
      expect(backend.position, const Duration(milliseconds: 1075));
      await controller.play();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 250)),
      );
      await tester.pump();
      expect(
        backend.position.inMicroseconds,
        inInclusiveRange(1000000, 1099999),
      );
      expect(native.seeks, nativeSeeks);
      await controller.pause();
      final held = backend.position;
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      expect(backend.position, held);
      await controller.close();
      expect(images.every((image) => image.debugDisposed), isTrue);
    },
  );

  for (final playing in [false, true]) {
    testWidgets(
      'Source mode retires a full-range buffer and preserves intent ($playing)',
      (tester) async {
        final images = await tester.runAsync(_images);
        final decoder = _Decoder();
        final native = _Native();
        final backend = GifSmoothLoopBackend(
          native: native,
          source: _Source(),
          decoder: decoder,
          onPosition: (_) {},
        );
        final controller = GifLoopPreviewController(
          backend: backend,
          start: Duration.zero,
          end: const Duration(seconds: 1),
          speed: 1,
          enabled: true,
          autoplay: false,
        );
        backend.serialize = controller.synchronize;
        await controller.initialize();
        await tester.pump(const Duration(milliseconds: 400));
        decoder.result.complete(
          GifLoopBuffer(
            images!,
            Duration.zero,
            GifLoopFrameClock([0, 500000], 1000000),
          ),
        );
        await tester.pump();
        await controller.seekTo(const Duration(milliseconds: 750));
        if (playing) await controller.play();
        final held = backend.position;
        await controller.synchronize(backend.useNativePlayback);
        expect(backend.buffered, isFalse);
        expect(backend.frame.value, isNull);
        expect(
          native.position.inMicroseconds,
          closeTo(held.inMicroseconds, 50000),
        );
        expect(native.playing, playing);
        expect(controller.playing, playing);
        await tester.pump();
        expect(images.every((image) => image.debugDisposed), isTrue);
        await controller.close();
      },
    );
  }

  testWidgets('a cancelled prepared buffer cannot replace a newer range', (
    tester,
  ) async {
    final images = await tester.runAsync(_images);
    final decoder = _Decoder();
    final native = _Native();
    final backend = GifSmoothLoopBackend(
      native: native,
      source: _Source(),
      decoder: decoder,
      onPosition: (_) {},
    );
    await backend.setRange(Duration.zero, const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 400));
    await backend.setRange(
      const Duration(seconds: 2),
      const Duration(seconds: 3),
    );
    expect(decoder.token!.isCancelled, isTrue);
    decoder.result.complete(
      GifLoopBuffer(
        images!,
        Duration.zero,
        GifLoopFrameClock([0, 500000], 1000000),
      ),
    );
    await tester.pump();
    expect(backend.buffered, isFalse);
    expect(images.every((image) => image.debugDisposed), isTrue);
    await backend.close();
  });

  testWidgets(
    'closing cancels preparation and waits before disposing native playback',
    (tester) async {
      final decoder = _Decoder();
      final native = _Native();
      final backend = GifSmoothLoopBackend(
        native: native,
        source: _Source(),
        decoder: decoder,
        onPosition: (_) {},
      );
      await backend.setRange(Duration.zero, const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 400));
      expect(decoder.token, isNotNull);
      final closed = backend.close();
      expect(decoder.token!.isCancelled, isTrue);
      expect(native.closed, isFalse);
      decoder.result.complete(null);
      await closed;
      expect(native.closed, isTrue);
    },
  );

  testWidgets(
    'an oversized/unavailable frame buffer keeps the native fallback explicit',
    (tester) async {
      final decoder = _Decoder();
      final native = _Native();
      final backend = GifSmoothLoopBackend(
        native: native,
        source: _Source(),
        decoder: decoder,
        onPosition: (_) {},
      );
      await backend.setRange(Duration.zero, const Duration(seconds: 30));
      await backend.play();
      await tester.pump(const Duration(milliseconds: 400));
      decoder.result.complete(null);
      await tester.pump();
      expect(backend.buffered, isFalse);
      expect(backend.status.value, GifSmoothPreviewStatus.nativeFallback);
      expect(native.playing, isTrue);
      await backend.close();
    },
  );
}

class _Source extends Mock implements GifPreparedSource {}

class _Runner extends Mock implements GifLoopCommandRunner {}

class _Decoder extends GifLoopBufferDecoder {
  _Decoder() : super(_Runner());
  final result = Completer<GifLoopBuffer?>();
  CancelToken? token;
  @override
  Future<GifLoopBuffer?> decode(
    GifPreparedSource source,
    Duration start,
    Duration end,
    CancelToken token,
  ) {
    this.token = token;
    return result.future;
  }
}

class _Native implements GifLoopPreviewBackend {
  var closed = false;
  var playing = false;
  var seeks = 0;
  @override
  Duration position = Duration.zero;
  @override
  Future<void> open() async {}
  @override
  Future<void> setRange(Duration start, Duration end) async {}
  @override
  Future<void> setSpeed(double speed) async {}
  @override
  Future<void> seek(Duration value) async {
    position = value;
    seeks++;
  }

  @override
  Future<void> pause() async {
    playing = false;
  }

  @override
  Future<void> play() async {
    playing = true;
  }

  @override
  Future<void> close() async {
    closed = true;
  }
}

Future<List<ui.Image>> _images() async {
  final result = <ui.Image>[];
  for (final color in [
    const ui.Color(0xffff0000),
    const ui.Color(0xff0000ff),
  ]) {
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawColor(color, ui.BlendMode.src);
    final picture = recorder.endRecording();
    try {
      result.add(await picture.toImage(2, 2));
    } finally {
      picture.dispose();
    }
  }
  return result;
}
