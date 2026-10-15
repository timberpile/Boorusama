import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'gif_conversion_service.dart';
import 'gif_editor_selection.dart';
import 'gif_loop_preview_controller.dart';
import 'gif_native_loop_preview.dart';
import 'gif_native_playhead.dart';
import 'gif_preview_controls.dart';
import 'gif_ffmpeg_runner.dart';
import 'gif_loop_buffer.dart';
import 'gif_smooth_loop_backend.dart';

class GifLoopVideoPreview extends StatefulWidget {
  const GifLoopVideoPreview({
    required this.source,
    required this.selection,
    required this.enabled,
    required this.position,
    this.sourceMode = false,
    this.prepareLoop = true,
    this.autoplay = true,
    this.onPlaybackIntent,
    this.previewSpeed,
    this.seekRequests,
    super.key,
  });
  final GifPreparedSource source;
  final GifEditorSelection selection;
  final bool enabled;
  final ValueNotifier<Duration> position;
  final bool sourceMode;
  final bool prepareLoop;
  final bool autoplay;
  final ValueChanged<bool>? onPlaybackIntent;
  final double? previewSpeed;
  final ValueListenable<(int, Duration)>? seekRequests;

  @override
  State<GifLoopVideoPreview> createState() => _GifLoopVideoPreviewState();
}

class _GifLoopVideoPreviewState extends State<GifLoopVideoPreview>
    with WidgetsBindingObserver {
  late final _source = widget.source;
  Player? _player;
  late VideoController _video;
  GifLoopPreviewController? _preview;
  GifSmoothLoopBackend? _smooth;
  StreamSubscription<String>? _errors;
  StreamSubscription<Duration>? _positions;
  StreamSubscription<bool>? _playing;
  StreamSubscription<bool>? _buffering;
  GifNativePlayhead? _nativePlayhead;
  StreamSubscription<PlayerLog>? _renderErrors;
  late var _creationFailed = false;
  var _foreground = true;

  @override
  void initState() {
    super.initState();
    _source.lease.retain();
    widget.seekRequests?.addListener(_seekRequested);
    WidgetsBinding.instance.addObserver(this);
    // The GIF editor and this native adapter are Android-only. In particular,
    // a desktop widget host has no Android video-output plugin to initialize.
    if (!Platform.isAndroid) {
      _creationFailed = true;
      return;
    }
    try {
      MediaKit.ensureInitialized();
      final player = _player = Player();
      _video = VideoController(player);
      final selected = widget.selection;
      final smooth = _smooth = GifSmoothLoopBackend(
        native: NativeGifLoopPreview(player, _source.lease.path),
        source: _source,
        decoder: const GifLoopBufferDecoder(FfmpegKitGifRunner()),
        onPosition: (value) {
          if (mounted) widget.position.value = value;
        },
      );
      final preview = _preview = GifLoopPreviewController(
        backend: smooth,
        start: widget.sourceMode ? Duration.zero : selected.start,
        end: widget.sourceMode ? selected.sourceDuration : selected.end,
        speed: widget.previewSpeed ?? selected.speed,
        enabled: widget.enabled,
        autoplay: widget.autoplay,
        initialPosition: widget.position.value,
      );
      smooth.serialize = preview.synchronize;
      final playhead = _nativePlayhead = GifNativePlayhead(
        start: widget.sourceMode ? Duration.zero : selected.start,
        end: widget.sourceMode ? selected.sourceDuration : selected.end,
        speed: widget.previewSpeed ?? selected.speed,
        onPosition: (position) {
          if (mounted && !smooth.buffered) widget.position.value = position;
        },
      );
      smooth.allowPreparation(
        _foreground &&
            widget.enabled &&
            widget.prepareLoop &&
            !widget.sourceMode,
      );
      preview.addListener(_changed);
      _positions = player.stream.position.listen((position) {
        if (mounted && !smooth.buffered) playhead.sample(position);
      });
      _playing = player.stream.playing.listen((playing) {
        playhead.setPlaying(
          playing &&
              preview.wantsPlayback &&
              _foreground &&
              widget.enabled &&
              !smooth.buffered,
        );
      });
      _buffering = player.stream.buffering.listen(playhead.setBuffering);
      _errors = player.stream.error.listen((_) => preview.markUnavailable());
      // media_kit 1.2.6 forwards only cplayer/stream errors to stream.error.
      // Renderer failures can unload the track without reaching that stream.
      _renderErrors = player.stream.log
          .where(
            (log) =>
                (log.level == 'error' || log.level == 'fatal') &&
                log.prefix.startsWith('vo/'),
          )
          .listen((_) => preview.markUnavailable());
      unawaited(_initializeVideo(preview));
    } catch (_) {
      _creationFailed = true;
    }
  }

  Future<void> _initializeVideo(GifLoopPreviewController preview) async {
    try {
      // VideoController creates its platform output asynchronously. Handle that
      // future before opening the source so a missing/failed output neither
      // escapes the widget nor leaves initialization waiting on a decoder.
      await _video.platform.future;
      if (mounted) await preview.initialize();
    } catch (_) {
      preview.markUnavailable();
    }
  }

  void _seekRequested() {
    final request = widget.seekRequests?.value;
    if (request != null) {
      _nativePlayhead?.setPlaying(false);
      _nativePlayhead?.sample(request.$2);
      final seek = _preview?.seekTo(request.$2);
      if (seek != null) unawaited(seek);
    }
  }

  void _changed() {
    if (!mounted) return;
    _nativePlayhead?.setPlaying(
      _preview!.playing &&
          (_player?.state.playing ?? false) &&
          !(_smooth?.buffered ?? false),
    );
    widget.onPlaybackIntent?.call(_preview!.wantsPlayback);
    setState(() {});
  }

  @override
  void didUpdateWidget(GifLoopVideoPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.seekRequests != widget.seekRequests) {
      oldWidget.seekRequests?.removeListener(_seekRequested);
      widget.seekRequests?.addListener(_seekRequested);
    }
    _smooth?.allowPreparation(
      _foreground && widget.enabled && widget.prepareLoop && !widget.sourceMode,
    );
    if (widget.sourceMode && !oldWidget.sourceMode) {
      final smooth = _smooth;
      final preview = _preview;
      if (smooth != null && preview != null) {
        unawaited(
          preview.synchronize(() async {
            // A quick return to Loop supersedes this queued handoff.
            if (mounted && widget.sourceMode) await smooth.useNativePlayback();
          }),
        );
      }
    }
    final selected = widget.selection;
    _nativePlayhead?.configure(
      start: widget.sourceMode ? Duration.zero : selected.start,
      end: widget.sourceMode ? selected.sourceDuration : selected.end,
      speed: widget.previewSpeed ?? selected.speed,
    );
    final update = _preview?.update(
      start: widget.sourceMode ? Duration.zero : selected.start,
      end: widget.sourceMode ? selected.sourceDuration : selected.end,
      speed: widget.previewSpeed ?? selected.speed,
      enabled: widget.enabled,
    );
    if (update != null) unawaited(update);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final foreground = _foreground = state == AppLifecycleState.resumed;
    if (!foreground) _nativePlayhead?.setPlaying(false);
    _smooth?.allowPreparation(
      _foreground && widget.enabled && widget.prepareLoop && !widget.sourceMode,
    );
    final update = _preview?.setForeground(foreground);
    if (update != null) unawaited(update);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.seekRequests?.removeListener(_seekRequested);
    _preview?.removeListener(_changed);
    unawaited(_release());
    super.dispose();
  }

  Future<void> _release() async {
    try {
      try {
        await _positions?.cancel();
        await _playing?.cancel();
        await _buffering?.cancel();
        _nativePlayhead?.dispose();
        await _errors?.cancel();
        await _renderErrors?.cancel();
      } finally {
        if (_preview case final preview?) {
          await preview.close();
        } else if (_smooth case final smooth?) {
          await smooth.close();
        } else {
          await _player?.dispose();
        }
      }
    } catch (_) {
      debugPrint('GIF preview player cleanup failed.');
    } finally {
      try {
        await _source.lease.release();
      } catch (_) {
        debugPrint('GIF preview source cleanup failed.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = _preview;
    final t = context.t.post.gif_editor;
    if (_creationFailed || preview == null || preview.unavailable) {
      return Center(child: Text(t.preview_unavailable));
    }
    return GifPreviewControls(
      controller: preview,
      enabled: widget.enabled,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Video(
            controller: _video,
            controls: NoVideoControls,
            aspectRatio: widget.selection.displayAspectRatio,
          ),
          ValueListenableBuilder(
            valueListenable: _smooth!.frame,
            builder: (context, image, _) => image == null
                ? const SizedBox.shrink()
                : ColoredBox(
                    color: Colors.black,
                    child: RawImage(image: image, fit: BoxFit.contain),
                  ),
          ),
          if (!widget.sourceMode)
            Align(
              alignment: Alignment.bottomCenter,
              child: ValueListenableBuilder(
                valueListenable: _smooth!.status,
                builder: (context, status, _) =>
                    status == GifSmoothPreviewStatus.buffered
                    ? const SizedBox.shrink()
                    : Container(
                        padding: const EdgeInsets.all(6),
                        color: Colors.black.withValues(alpha: .7),
                        child: Text(
                          status == GifSmoothPreviewStatus.preparing
                              ? context.t.gif_trim.preparing_preview
                              : context.t.gif_trim.native_preview,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                          ),
                        ),
                      ),
              ),
            ),
        ],
      ),
    );
  }
}
