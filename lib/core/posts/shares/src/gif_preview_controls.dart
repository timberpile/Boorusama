import 'dart:async';

import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

import 'gif_loop_preview_controller.dart';

/// Editor-local controls; tapping the picture reveals controls without toggling
/// playback, so an obscured Pause button cannot stop playback accidentally.
class GifPreviewControls extends StatefulWidget {
  const GifPreviewControls({
    required this.controller,
    required this.enabled,
    required this.child,
    super.key,
  });

  final GifLoopPreviewController controller;
  final bool enabled;
  final Widget child;

  @override
  State<GifPreviewControls> createState() => _GifPreviewControlsState();
}

class _GifPreviewControlsState extends State<GifPreviewControls> {
  Timer? _hideTimer;
  var _visible = true;
  var _wasPlaying = false;

  @override
  void initState() {
    super.initState();
    _wasPlaying = widget.controller.playing;
    widget.controller.addListener(_changed);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scheduleHide();
  }

  @override
  void didUpdateWidget(GifPreviewControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_changed);
      widget.controller.addListener(_changed);
      _visible = true;
      _wasPlaying = false;
      _scheduleHide();
    }
  }

  void _changed() {
    final playing = widget.controller.playing;
    if (playing != _wasPlaying) {
      _visible = true;
      _wasPlaying = playing;
      _scheduleHide();
    }
    if (mounted) setState(() {});
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    if (!widget.controller.playing ||
        MediaQuery.accessibleNavigationOf(context)) {
      return;
    }
    _hideTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _visible = false);
    });
  }

  void _reveal() {
    setState(() => _visible = true);
    _scheduleHide();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    widget.controller.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final preview = widget.controller;
    final t = context.t.post.gif_editor;
    final visible =
        _visible ||
        !preview.playing ||
        MediaQuery.accessibleNavigationOf(context);
    return Stack(
      fit: StackFit.expand,
      alignment: Alignment.center,
      children: [
        Positioned.fill(
          child: GestureDetector(
            key: const ValueKey('gif-preview-surface'),
            behavior: HitTestBehavior.opaque,
            onTap: _reveal,
            child: widget.child,
          ),
        ),
        if (!preview.ready)
          const Center(child: CircularProgressIndicator())
        else
          Center(
            child: IgnorePointer(
              ignoring: !visible,
              child: AnimatedOpacity(
                opacity: visible ? 1 : 0,
                duration: const Duration(milliseconds: 200),
                child: IconButton.filled(
                  key: const ValueKey('gif-preview-play-pause'),
                  tooltip: preview.playing ? t.pause : t.play,
                  onPressed: !widget.enabled
                      ? null
                      : () {
                          unawaited(
                            preview.playing ? preview.pause() : preview.play(),
                          );
                        },
                  icon: Icon(preview.playing ? Icons.pause : Icons.play_arrow),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
