import 'dart:async';

import 'package:flutter/foundation.dart';

/// Commands affect one editor-local player, never the post viewer's player.
abstract interface class GifLoopPreviewBackend {
  Future<void> open();
  Future<void> setRange(Duration start, Duration end);
  Duration get position;
  Future<void> setSpeed(double speed);
  Future<void> seek(Duration position);
  Future<void> play();
  Future<void> pause();
  Future<void> close();
}

/// Serializes range changes and playback intent. The backend owns repetition;
/// this controller never polls the end position to seek at the loop seam.
class GifLoopPreviewController extends ChangeNotifier {
  GifLoopPreviewController({
    required this.backend,
    required Duration start,
    required Duration end,
    required double speed,
    required bool enabled,
    bool autoplay = true,
    Duration? initialPosition,
  }) : _start = start,
       _end = end,
       _speed = speed,
       _enabled = enabled,
       _wantsPlayback = autoplay,
       _pendingPosition = initialPosition;

  final GifLoopPreviewBackend backend;
  Duration _start;
  Duration _end;
  double _speed;
  var _foreground = true;
  bool _enabled;
  bool _wantsPlayback;
  var _initialized = false;
  var _closed = false;
  var _notifierDisposed = false;
  var _generation = 0;
  var _needsSeek = true;
  Duration? _pendingPosition;
  var ready = false;
  var unavailable = false;
  Duration? _appliedStart;
  Duration? _appliedEnd;
  double? _appliedSpeed;
  var _queue = Future<void>.value();
  Future<void>? _closeFuture;

  bool get wantsPlayback => _wantsPlayback;

  bool get playing =>
      ready && _enabled && _foreground && _wantsPlayback && !unavailable;

  Future<void> initialize() => _enqueue(() async {
    await backend.open();
    if (_closed) return;
    _initialized = true;
    await _apply(_generation, restart: _pendingPosition == null);
  });

  Future<void> update({
    required Duration start,
    required Duration end,
    required double speed,
    required bool enabled,
  }) {
    if (_closed ||
        (_start == start &&
            _end == end &&
            _speed == speed &&
            _enabled == enabled)) {
      return _queue;
    }
    _start = start;
    _end = end;
    _speed = speed;
    _enabled = enabled;
    if (!enabled) _wantsPlayback = false;
    final generation = ++_generation;
    return _enqueue(() => _apply(generation));
  }

  Future<void> play() {
    if (_closed || !_enabled || unavailable) return _queue;
    _wantsPlayback = true;
    final generation = ++_generation;
    return _enqueue(() => _apply(generation));
  }

  /// Scrubbing is an explicit pause. Newer requests supersede queued seeks.
  Future<void> seekTo(Duration position) {
    if (_closed || unavailable) return _queue;
    _wantsPlayback = false;
    _pendingPosition = Duration(
      microseconds: position.inMicroseconds.clamp(
        _start.inMicroseconds,
        _end.inMicroseconds - 1,
      ),
    );
    _needsSeek = true;
    final generation = ++_generation;
    return _enqueue(() => _apply(generation));
  }

  Future<void> pause() {
    if (_closed) return _queue;
    _wantsPlayback = false;
    final generation = ++_generation;
    return _enqueue(() => _apply(generation));
  }

  /// Background suspension preserves user intent, unlike an explicit Pause.
  Future<void> setForeground(bool foreground) {
    if (_closed || _foreground == foreground) return _queue;
    _foreground = foreground;
    final generation = ++_generation;
    return _enqueue(() => _apply(generation));
  }

  bool _current(int generation) => !_closed && generation == _generation;

  Future<void> _apply(int generation, {bool restart = false}) async {
    if (!_current(generation) || !_initialized || unavailable) return;
    final start = _start;
    final end = _end;
    final speed = _speed;
    await backend.pause();
    if (!_current(generation)) return;
    final changedRange = _appliedStart != start || _appliedEnd != end;
    if (changedRange) {
      final position = _pendingPosition ?? backend.position;
      _pendingPosition = position >= start && position < end ? position : start;
      _needsSeek = true;
      await backend.setRange(start, end);
      _appliedStart = start;
      _appliedEnd = end;
      if (!_current(generation)) return;
    }
    if (_appliedSpeed != speed) {
      await backend.setSpeed(speed);
      _appliedSpeed = speed;
      if (!_current(generation)) return;
    }
    if (restart || _needsSeek) {
      final held = _pendingPosition ?? backend.position;
      await backend.seek(restart || held < start || held >= end ? start : held);
      if (!_current(generation)) return;
      _needsSeek = false;
      _pendingPosition = null;
    }
    if (_enabled && _foreground && _wantsPlayback) await backend.play();
    if (!_current(generation)) return;
    ready = true;
    notifyListeners();
  }

  void markUnavailable() {
    if (_closed) return;
    unavailable = true;
    _wantsPlayback = false;
    ++_generation;
    unawaited(_enqueue(backend.pause));
    notifyListeners();
  }

  Future<void> synchronize(Future<void> Function() action) =>
      _enqueue(() async {
        if (!unavailable) await action();
      });

  Future<void> _enqueue(Future<void> Function() action) {
    return _queue = _queue.then((_) async {
      if (_closed) return;
      try {
        await action();
      } catch (_) {
        if (!_closed) {
          unavailable = true;
          _wantsPlayback = false;
          notifyListeners();
        }
      }
    });
  }

  /// Wait for in-flight commands before disposing the native player. The widget
  /// releases its source lease only after this future has completed.
  Future<void> close() {
    if (_closeFuture case final existing?) return existing;
    _closed = true;
    ++_generation;
    _closeFuture = _queue.then((_) => backend.close());
    dispose();
    return _closeFuture!;
  }

  @override
  void dispose() {
    if (_notifierDisposed) return;
    _notifierDisposed = true;
    unawaited(close());
    super.dispose();
  }
}
