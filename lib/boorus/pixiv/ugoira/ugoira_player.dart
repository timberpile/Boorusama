import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

import 'ugoira_archive.dart';
import 'ugoira_frames.dart';

/// A stable poster and animation surface for one viewer occurrence.
/// Preparation can finish before this surface is active.
class PixivUgoiraPlayer extends StatefulWidget {
  const PixivUgoiraPlayer({
    required this.active,
    required this.prepared,
    required this.failed,
    required this.onRetry,
    required this.poster,
    this.downloadProgress,
    this.decodeFrame = decodePixivUgoiraFrame,
    super.key,
  });

  final bool active;
  final PreparedPixivUgoira? prepared;
  final bool failed;
  final VoidCallback? onRetry;
  final Widget poster;
  final ValueListenable<double?>? downloadProgress;
  final Future<ui.Image> Function(Uint8List bytes) decodeFrame;

  @override
  State<PixivUgoiraPlayer> createState() => _PixivUgoiraPlayerState();
}

class _PixivUgoiraPlayerState extends State<PixivUgoiraPlayer>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_tick);
  final _decoded = <int, ui.Image>{};
  PixivUgoiraAnimation? _animation;
  int? _displayed;
  var _positionUs = 0;
  var _lastTick = Duration.zero;
  var _decoding = false;
  var _failed = false;
  var _generation = 0;

  @override
  void initState() {
    super.initState();
    _updateAnimation();
  }

  @override
  void didUpdateWidget(covariant PixivUgoiraPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active ||
        !identical(oldWidget.prepared, widget.prepared)) {
      _updateAnimation();
    }
  }

  void _updateAnimation() {
    _generation++;
    _ticker.stop();
    _clearFrames();
    _failed = false;
    _decoding = false;
    _displayed = null;
    _positionUs = 0;
    _lastTick = Duration.zero;
    final prepared = widget.active ? widget.prepared : null;
    _animation = prepared?.animation;
    if (prepared != null) {
      _decoded.addAll(prepared.cloneOpeningFrames());
      _displayed = 0;
      _ticker.start();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _clearFrames();
    super.dispose();
  }

  void _clearFrames() {
    for (final frame in _decoded.values) {
      frame.dispose();
    }
    _decoded.clear();
  }

  void _tick(Duration elapsed) {
    final animation = _animation!;
    _positionUs =
        (_positionUs + (elapsed - _lastTick).inMicroseconds) %
        (animation.durationMilliseconds * Duration.microsecondsPerMillisecond);
    _lastTick = elapsed;
    _renderPosition();
  }

  void _renderPosition() {
    final animation = _animation!;
    final target = animation.frameAt(
      _positionUs ~/ Duration.microsecondsPerMillisecond,
    );
    if (_decoded.containsKey(target) && _displayed != target) {
      setState(() => _displayed = target);
    }

    final next = (target + 1) % animation.frames.length;
    // A slow decode may leave the last displayed frame visible while the
    // playback clock moves on. Keep only that image, the target, and its next.
    _decoded.removeWhere((index, image) {
      if (index == _displayed || index == target || index == next) return false;
      image.dispose();
      return true;
    });
    if (_decoding) return;
    final candidate = !_decoded.containsKey(target)
        ? target
        : !_decoded.containsKey(next)
        ? next
        : null;
    if (candidate != null) unawaited(_prepareFrame(animation, candidate));
  }

  Future<void> _prepareFrame(PixivUgoiraAnimation animation, int index) async {
    _decoding = true;
    final generation = _generation;
    try {
      final image = await widget.decodeFrame(animation.frames[index]);
      if (!mounted || generation != _generation) {
        image.dispose();
        return;
      }
      _decoded[index] = image;
      _decoding = false;
      _renderPosition();
    } catch (_) {
      if (mounted && generation == _generation) {
        _decoding = false;
        _fail();
      }
    }
  }

  void _fail() {
    _ticker.stop();
    _clearFrames();
    setState(() {
      _animation = null;
      _displayed = null;
      _failed = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final image = _decoded[_displayed];
    final failed = widget.active && (_failed || widget.failed);
    final progress = widget.downloadProgress;
    return Stack(
      fit: StackFit.passthrough,
      children: [
        Visibility(
          visible: image == null,
          maintainSize: true,
          maintainState: true,
          maintainAnimation: true,
          child: widget.poster,
        ),
        if (image != null)
          Positioned.fill(
            child: IgnorePointer(
              child: RawImage(image: image, fit: BoxFit.contain),
            ),
          ),
        if (widget.active && progress != null && !failed && image == null)
          Positioned.fill(
            child: IgnorePointer(
              child: Center(
                child: SizedBox.square(
                  dimension: 24,
                  child: ValueListenableBuilder(
                    valueListenable: progress,
                    builder: (context, value, child) =>
                        CircularProgressIndicator(
                          value: value,
                          strokeWidth: 2,
                          semanticsLabel: t.ugoira.loading,
                        ),
                  ),
                ),
              ),
            ),
          ),
        if (failed)
          PositionedDirectional(
            start: 8,
            end: 8,
            bottom: 8,
            child: Center(
              child: Material(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    alignment: WrapAlignment.center,
                    children: [
                      Text(t.ugoira.unavailable),
                      if (widget.onRetry case final retry?)
                        TextButton(
                          onPressed: retry,
                          child: Text(t.generic.action.retry),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
