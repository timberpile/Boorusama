import 'dart:async';

import 'package:boorusama/core/posts/shares/src/gif_loop_preview_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late _Backend backend;
  late GifLoopPreviewController controller;
  setUp(() {
    backend = _Backend();
    controller = GifLoopPreviewController(
      backend: backend, start: const Duration(seconds: 1),
      end: const Duration(seconds: 2), speed: 1, enabled: true,
    );
  });
  tearDown(() async => controller.close());

  test('initial selection is prepared and remains paused', () async {
    await controller.initialize();
    expect(controller.ready, isTrue);
    expect(controller.playing, isFalse);
    expect(backend.calls, ['open', 'pause', 'range:1000000:2000000', 'speed:1.0', 'seek:1000000']);
  });

  test('pause holds position; every Play explicitly starts at selection start', () async {
    await controller.initialize();
    await controller.playFromStart();
    backend.calls.clear();
    await controller.pause();
    expect(backend.calls, ['pause']);
    expect(controller.playing, isFalse);
    await controller.playFromStart();
    expect(backend.calls, ['pause', 'pause', 'seek:1000000', 'play']);
    expect(controller.playing, isTrue);
  });

  test('range change seeks within new range without resuming paused playback', () async {
    await controller.initialize();
    backend.calls.clear();
    await controller.update(start: const Duration(seconds: 3),
      end: const Duration(seconds: 4), speed: 2, enabled: true);
    expect(backend.calls, ['pause', 'range:3000000:4000000', 'speed:2.0', 'seek:3000000']);
    expect(controller.playing, isFalse);
  });

  test('stale selection operation cannot resume after a newer Pause', () async {
    await controller.initialize();
    await controller.playFromStart();
    backend.calls.clear();
    backend.rangeGate = Completer<void>();
    final update = controller.update(start: const Duration(seconds: 3),
      end: const Duration(seconds: 4), speed: 1, enabled: true);
    await backend.rangeEntered.future;
    final pause = controller.pause();
    backend.rangeGate!.complete();
    await Future.wait([update, pause]);
    expect(backend.calls.where((c) => c == 'play'), isEmpty);
    expect(backend.calls.last, 'seek:3000000');
    expect(controller.playing, isFalse);
  });

  test('disable and re-enable do not unexpectedly restart playback', () async {
    await controller.initialize();
    await controller.playFromStart();
    await controller.update(start: const Duration(seconds: 1),
      end: const Duration(seconds: 2), speed: 1, enabled: false);
    await controller.update(start: const Duration(seconds: 1),
      end: const Duration(seconds: 2), speed: 1, enabled: true);
    expect(controller.playing, isFalse);
  });

  test('close waits for in-flight native operation before closing backend', () async {
    await controller.initialize();
    backend.rangeGate = Completer<void>();
    final update = controller.update(start: const Duration(seconds: 3),
      end: const Duration(seconds: 4), speed: 1, enabled: true);
    await backend.rangeEntered.future;
    final close = controller.close();
    expect(backend.calls, isNot(contains('close')));
    backend.rangeGate!.complete();
    await Future.wait([update, close]);
    expect(backend.calls.last, 'close');
    expect(backend.calls.where((c) => c == 'close'), hasLength(1));
  });
}

class _Backend implements GifLoopPreviewBackend {
  final calls = <String>[];
  Completer<void>? rangeGate;
  final rangeEntered = Completer<void>();
  @override
  Future<void> open() async { calls.add('open'); }
  @override
  Future<void> setRange(Duration start, Duration end) async {
    calls.add('range:${start.inMicroseconds}:${end.inMicroseconds}');
    if (rangeGate != null) {
      if (!rangeEntered.isCompleted) rangeEntered.complete();
      await rangeGate!.future;
    }
  }
  @override
  Future<void> setSpeed(double speed) async { calls.add('speed:$speed'); }
  @override
  Future<void> seek(Duration position) async { calls.add('seek:${position.inMicroseconds}'); }
  @override
  Future<void> play() async { calls.add('play'); }
  @override
  Future<void> pause() async { calls.add('pause'); }
  @override
  Future<void> close() async { calls.add('close'); }
}
