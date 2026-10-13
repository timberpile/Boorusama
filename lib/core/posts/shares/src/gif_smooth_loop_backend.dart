import 'dart:async';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import 'gif_conversion_service.dart';
import 'gif_loop_buffer.dart';
import 'gif_loop_preview_controller.dart';

enum GifSmoothPreviewStatus { preparing, buffered, nativeFallback }

/// Keeps the established native player for source browsing and large selections.
/// Small loops are decoded once, then scheduled by PTS without a seek at each
/// seam. Preparation is debounced, cancellable and serialized across edits.
class GifSmoothLoopBackend implements GifLoopPreviewBackend {
  GifSmoothLoopBackend({
    required this.native,
    required this.source,
    required this.decoder,
    required this.onPosition,
  }) {
    _ticker = Ticker((_) => _tick());
  }
  final GifLoopPreviewBackend native;
  final GifPreparedSource source;
  final GifLoopBufferDecoder decoder;
  final ValueChanged<Duration> onPosition;
  final frame = ValueNotifier<ui.Image?>(null);
  final status = ValueNotifier(GifSmoothPreviewStatus.preparing);
  late final Ticker _ticker;
  final _watch = Stopwatch();
  GifLoopBuffer? _buffer;
  final _retired = <GifLoopBuffer>[];
  double _baseTime = 0;
  double _speed = 1;
  var _playing = false;
  var _closed = false;
  var _generation = 0;
  Duration? _heldNativePosition;
  Duration _start = Duration.zero;
  Duration _end = Duration.zero;
  var _mayPrepare = true;
  Timer? _debounce;
  CancelToken? _token;
  var _jobs = Future<void>.value();

  // Bound by the widget to the preview controller's command queue. Adoption
  // must not race a newer range, seek, pause or native-player disposal.
  Future<void> Function(Future<void> Function()) serialize = (action) =>
      action();

  bool get buffered => _buffer != null;
  int get _elapsed => (_baseTime + _watch.elapsedMicroseconds * _speed).round();
  @override
  Duration get position => switch (_buffer) {
    final buffer? =>
      buffer.start + Duration(microseconds: _elapsed % buffer.clock.duration),
    _ => _heldNativePosition ?? native.position,
  };

  @override
  Future<void> open() => native.open();

  void _clear() {
    _ticker.stop();
    _watch.stop();
    _watch.reset();
    frame.value = null;
    final buffer = _buffer;
    _buffer = null;
    if (buffer == null) return;
    // RawImage may still reference the old image until the next rendered frame.
    _retired.add(buffer);
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (_retired.remove(buffer)) buffer.dispose();
    });
    SchedulerBinding.instance.scheduleFrame();
  }

  @override
  Future<void> setRange(Duration start, Duration end) async {
    final generation = ++_generation;
    _debounce?.cancel();
    _token?.cancel();
    _clear();
    _start = start;
    _end = end;
    await native.setRange(start, end);
    if (_closed || generation != _generation) return;
    _schedulePreparation();
  }

  void allowPreparation(bool value) {
    if (_closed || _mayPrepare == value) return;
    _mayPrepare = value;
    ++_generation;
    _debounce?.cancel();
    _token?.cancel();
    if (value && !buffered && _end > _start) _schedulePreparation();
  }

  /// Called through the controller queue when Source mode takes ownership.
  /// The range can be unchanged for a full-source loop, so setRange alone is
  /// insufficient to retire its buffer and resume the native player.
  Future<void> useNativePlayback() async {
    if (_closed) return;
    allowPreparation(false);
    if (!buffered) return;
    final held = position;
    _clear();
    _heldNativePosition = held;
    await native.seek(held);
    if (_playing) {
      _heldNativePosition = null;
      await native.play();
    }
    status.value = GifSmoothPreviewStatus.nativeFallback;
  }

  void _schedulePreparation() {
    if (!_mayPrepare || _closed) return;
    final generation = _generation;
    final start = _start;
    final end = _end;
    status.value = GifSmoothPreviewStatus.preparing;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _jobs = _jobs.then((_) => _prepare(generation, start, end));
    });
  }

  Future<void> _prepare(int generation, Duration start, Duration end) async {
    if (_closed || !_mayPrepare || generation != _generation) return;
    final token = _token = CancelToken();
    GifLoopBuffer? candidate;
    try {
      candidate = await decoder.decode(source, start, end, token);
      if (_closed || generation != _generation || token.isCancelled) return;
      if (candidate == null) {
        status.value = GifSmoothPreviewStatus.nativeFallback;
        return;
      }
      await serialize(() async {
        if (_closed || generation != _generation) return;
        final readyBuffer = candidate!;
        final held = _heldNativePosition ?? native.position;
        await native.pause();
        if (_closed || generation != _generation) return;
        _baseTime = (held.inMicroseconds - readyBuffer.start.inMicroseconds)
            .clamp(0, readyBuffer.clock.duration - 1)
            .toDouble();
        _buffer = readyBuffer;
        candidate = null;
        status.value = GifSmoothPreviewStatus.buffered;
        _watch.reset();
        _tick();
        if (_playing) {
          _watch.start();
          if (!_ticker.isActive) _ticker.start();
        }
      });
    } catch (_) {
      if (!_closed && generation == _generation) {
        status.value = GifSmoothPreviewStatus.nativeFallback;
        // Preserve playback after an unsuccessful switch to the buffer.
        await serialize(() async {
          if (!_closed && generation == _generation && _playing) {
            await native.play();
          }
        });
      }
    } finally {
      candidate?.dispose();
      if (identical(_token, token)) _token = null;
      if (!_closed && generation == _generation && token.isCancelled) {
        status.value = GifSmoothPreviewStatus.nativeFallback;
      }
    }
  }

  void _tick() {
    final buffer = _buffer;
    if (_closed || buffer == null) return;
    frame.value = buffer.images[buffer.clock.frameAt(_elapsed)];
    onPosition(position);
  }

  void _hold() {
    _baseTime = _elapsed.toDouble();
    _watch.stop();
    _watch.reset();
    _ticker.stop();
  }

  @override
  Future<void> setSpeed(double speed) async {
    _hold();
    _speed = speed;
    await native.setSpeed(speed);
    if (buffered && _playing) {
      _watch.start();
      _ticker.start();
    }
  }

  @override
  Future<void> seek(Duration position) async {
    final buffer = _buffer;
    if (buffer == null) {
      _heldNativePosition = position;
      await native.seek(position);
      return;
    }
    _baseTime = (position.inMicroseconds - buffer.start.inMicroseconds)
        .clamp(0, buffer.clock.duration - 1)
        .toDouble();
    _watch.reset();
    _tick();
  }

  @override
  Future<void> play() async {
    _playing = true;
    if (buffered) {
      _watch.start();
      if (!_ticker.isActive) _ticker.start();
    } else {
      _heldNativePosition = null;
      await native.play();
    }
  }

  @override
  Future<void> pause() async {
    if (!buffered && _playing) _heldNativePosition = native.position;
    _playing = false;
    _hold();
    await native.pause();
  }

  @override
  Future<void> close() async {
    _closed = true;
    ++_generation;
    _debounce?.cancel();
    _token?.cancel();
    _ticker.dispose();
    _watch.stop();
    try {
      try {
        await _jobs;
      } finally {
        await native.close();
      }
    } finally {
      _buffer?.dispose();
      for (final buffer in _retired) {
        buffer.dispose();
      }
      _retired.clear();
      frame.dispose();
      status.dispose();
    }
  }
}
