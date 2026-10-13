import 'dart:async';

import 'package:boorusama/core/posts/shares/src/gif_loop_preview_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late _Backend backend;
  late GifLoopPreviewController controller;

  setUp(() {
    backend = _Backend();
    controller = GifLoopPreviewController(
      backend: backend,
      start: const Duration(seconds: 10),
      end: const Duration(seconds: 20),
      speed: 1,
      enabled: true,
    );
  });
  tearDown(() => controller.close());

  for (final autoplay in [false, true]) {
    test(
      'recreated preview restores its held position (autoplay=$autoplay)',
      () async {
        await controller.close();
        backend = _Backend();
        controller = GifLoopPreviewController(
          backend: backend,
          start: const Duration(seconds: 10),
          end: const Duration(seconds: 20),
          speed: 1,
          enabled: true,
          autoplay: autoplay,
          initialPosition: const Duration(seconds: 15),
        );
        await controller.initialize();
        expect(backend.position, const Duration(seconds: 15));
        expect(controller.playing, autoplay);
        await controller.play();
        expect(backend.position, const Duration(seconds: 15));
      },
    );
  }

  test(
    'restored position outside an applied trim starts at the new boundary',
    () async {
      await controller.close();
      backend = _Backend();
      controller = GifLoopPreviewController(
        backend: backend,
        start: const Duration(seconds: 10),
        end: const Duration(seconds: 20),
        speed: 1,
        enabled: true,
        autoplay: false,
        initialPosition: const Duration(seconds: 5),
      );
      await controller.initialize();
      expect(backend.position, const Duration(seconds: 10));
      expect(controller.playing, isFalse);
    },
  );

  test('scrubbing pauses and newer queued requests win', () async {
    await controller.initialize();
    final first = controller.seekTo(const Duration(seconds: 11));
    final second = controller.seekTo(const Duration(seconds: 14));
    await Future.wait([first, second]);
    expect(controller.playing, isFalse);
    expect(backend.position, const Duration(seconds: 14));
    await controller.play();
    expect(backend.position, const Duration(seconds: 14));
    expect(controller.playing, isTrue);
  });

  test('scrubbing before initialization survives opening the player', () async {
    final open = controller.initialize();
    final seek = controller.seekTo(const Duration(seconds: 15));
    await Future.wait([open, seek]);
    expect(backend.position, const Duration(seconds: 15));
    expect(controller.playing, isFalse);
  });

  test('scrubbing is bounded by the active playback range', () async {
    await controller.initialize();
    await controller.seekTo(Duration.zero);
    expect(backend.position, const Duration(seconds: 10));
    await controller.seekTo(const Duration(seconds: 30));
    expect(backend.position.inMicroseconds, 19999999);
  });

  test('source-mode range changes are applied before the seek', () async {
    await controller.initialize();
    final update = controller.update(
      start: Duration.zero,
      end: const Duration(minutes: 2),
      speed: .5,
      enabled: true,
    );
    final seek = controller.seekTo(const Duration(seconds: 43));
    await Future.wait([update, seek]);
    expect(backend.start, Duration.zero);
    expect(backend.end, const Duration(minutes: 2));
    expect(backend.position, const Duration(seconds: 43));
    expect(backend.speed, .5);
    expect(controller.playing, isFalse);
  });

  test(
    'serialized asynchronous preparation completes before disposal',
    () async {
      await controller.initialize();
      final entered = Completer<void>();
      final release = Completer<void>();
      final job = controller.synchronize(() async {
        entered.complete();
        await release.future;
      });
      await entered.future;
      final close = controller.close();
      expect(backend.closed, isFalse);
      release.complete();
      await Future.wait([job, close]);
      expect(backend.closed, isTrue);
    },
  );
}

class _Backend implements GifLoopPreviewBackend {
  @override
  Duration position = Duration.zero;
  Duration start = Duration.zero;
  Duration end = Duration.zero;
  double speed = 1;
  var closed = false;

  @override
  Future<void> open() async {}
  @override
  Future<void> setRange(Duration start, Duration end) async {
    this.start = start;
    this.end = end;
  }

  @override
  Future<void> setSpeed(double speed) async {
    this.speed = speed;
  }

  @override
  Future<void> seek(Duration position) async {
    this.position = position;
  }

  @override
  Future<void> play() async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> close() async {
    closed = true;
  }
}
