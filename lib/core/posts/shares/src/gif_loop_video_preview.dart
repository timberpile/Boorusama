import 'dart:async';
import 'dart:io';

import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'gif_conversion_service.dart';
import 'gif_editor_selection.dart';
import 'gif_loop_preview_controller.dart';

class GifLoopVideoPreview extends StatefulWidget {
  const GifLoopVideoPreview({
    required this.source,
    required this.selection,
    required this.enabled,
    super.key,
  });
  final GifPreparedSource source;
  final GifEditorSelection selection;
  final bool enabled;

  @override
  State<GifLoopVideoPreview> createState() => _GifLoopVideoPreviewState();
}

class _GifLoopVideoPreviewState extends State<GifLoopVideoPreview>
    with WidgetsBindingObserver {
  late final _source = widget.source;
  Player? _player;
  VideoController? _video;
  GifLoopPreviewController? _preview;
  StreamSubscription<String>? _errors;
  var _creationFailed = false;

  @override
  void initState() {
    super.initState();
    _source.lease.retain();
    WidgetsBinding.instance.addObserver(this);
    try {
      MediaKit.ensureInitialized();
      final player = _player = Player();
      _video = VideoController(player);
      final selected = widget.selection;
      final preview = _preview = GifLoopPreviewController(
        backend: _NativeGifLoopPreview(player, _source.lease.path),
        start: selected.start,
        end: selected.end,
        speed: selected.speed,
        enabled: widget.enabled,
      );
      preview.addListener(_changed);
      _errors = player.stream.error.listen((_) => preview.markUnavailable());
      unawaited(preview.initialize());
    } catch (_) {
      _creationFailed = true;
    }
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(GifLoopVideoPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    final selected = widget.selection;
    final update = _preview?.update(
      start: selected.start,
      end: selected.end,
      speed: selected.speed,
      enabled: widget.enabled,
    );
    if (update != null) unawaited(update);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      final pause = _preview?.pause();
      if (pause != null) unawaited(pause);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _preview?.removeListener(_changed);
    unawaited(_release());
    super.dispose();
  }

  Future<void> _release() async {
    try {
      try {
        await _errors?.cancel();
      } finally {
        if (_preview case final preview?) {
          await preview.close();
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
    return Stack(
      alignment: Alignment.center,
      children: [
        Video(controller: _video!, controls: NoVideoControls, fit: BoxFit.contain),
        if (!preview.ready)
          const Center(child: CircularProgressIndicator())
        else
          IconButton.filled(
            key: const ValueKey('gif-preview-play-pause'),
            tooltip: preview.playing ? t.pause : t.play,
            onPressed: !widget.enabled ? null : () {
              unawaited(preview.playing ? preview.pause() : preview.playFromStart());
            },
            icon: Icon(preview.playing ? Icons.pause : Icons.play_arrow),
          ),
      ],
    );
  }
}

class _NativeGifLoopPreview implements GifLoopPreviewBackend {
  const _NativeGifLoopPreview(this.player, this.path);
  final Player player;
  final String path;

  @override
  Future<void> open() async {
    await player.setVolume(0);
    // Native EOF repetition also covers a selection ending at source duration.
    await player.setPlaylistMode(PlaylistMode.single);
    await player.open(Media(File(path).uri.toString()), play: false);
  }

  @override
  Future<void> setRange(Duration start, Duration end) async {
    if (player.platform is! NativePlayer) {
      throw UnsupportedError('Native GIF preview required');
    }
    // This Android-only adapter uses the documented libmpv escape hatch. The
    // web stub does not expose setProperty; keep that platform outside the call.
    final dynamic native = player.platform;
    await native.setProperty('ab-loop-b', 'no');
    await native.setProperty('ab-loop-a', (start.inMicroseconds / 1000000).toStringAsFixed(6));
    await native.setProperty('ab-loop-b', (end.inMicroseconds / 1000000).toStringAsFixed(6));
    await native.setProperty('ab-loop-count', 'inf');
  }

  @override
  Future<void> setSpeed(double speed) => player.setRate(speed);
  @override
  Future<void> seek(Duration position) async {
    // Keep source-frame boundaries precise; do not quantize to milliseconds.
    final dynamic native = player.platform;
    await native.command([
      'seek', (position.inMicroseconds / 1000000).toStringAsFixed(6),
      'absolute+exact',
    ]);
  }
  @override
  Future<void> play() => player.play();
  @override
  Future<void> pause() => player.pause();
  @override
  Future<void> close() => player.dispose();
}
