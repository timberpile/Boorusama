import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// Interpolates coarse native timestamps for the timeline. Native samples remain
/// authoritative after seeks and loop wraps; this never drives player looping.
class GifNativePlayhead {
  GifNativePlayhead({
    required this.onPosition,
    required Duration start,
    required Duration end,
    required double speed,
  }) : _start = start,
       _end = end,
       _speed = speed,
       _position = start {
    _ticker = Ticker((elapsed) {
      _elapsed = elapsed;
      onPosition(_current);
    });
  }

  final ValueChanged<Duration> onPosition;
  late final Ticker _ticker;
  Duration _start;
  Duration _end;
  double _speed;
  Duration _position;
  Duration _elapsed = Duration.zero;
  Duration _sampledAt = Duration.zero;
  var _playing = false;
  var _buffering = false;

  Duration get _current {
    // Stop extrapolating if native updates cease without a buffering event.
    final delta = (_elapsed - _sampledAt).inMicroseconds.clamp(0, 400000);
    return Duration(
      microseconds: (_position.inMicroseconds + delta * _speed).round().clamp(
        _start.inMicroseconds,
        _end.inMicroseconds - 1,
      ),
    );
  }

  void sample(Duration position) {
    _position = position;
    _sampledAt = _elapsed;
    onPosition(_current);
  }

  void configure({
    required Duration start,
    required Duration end,
    required double speed,
  }) {
    _position = _current;
    _sampledAt = _elapsed;
    _start = start;
    _end = end;
    _speed = speed;
  }

  void setPlaying(bool value) {
    _playing = value;
    _update();
  }

  void setBuffering(bool value) {
    _buffering = value;
    _update();
  }

  void _update() {
    final active = _playing && !_buffering;
    if (active == _ticker.isActive) return;
    _position = _current;
    _elapsed = Duration.zero;
    _sampledAt = Duration.zero;
    if (active) {
      _ticker.start();
    } else {
      _ticker.stop();
      onPosition(_position);
    }
  }

  void dispose() => _ticker.dispose();
}
