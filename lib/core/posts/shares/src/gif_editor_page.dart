import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';
import 'package:video_player/video_player.dart';

import 'gif_conversion_service.dart';
import 'gif_background_execution.dart';
import 'gif_editor_controller.dart';
import 'gif_editor_selection.dart';
import 'gif_error_message.dart';
import 'gif_export_contract.dart';
import 'gif_save_service.dart';
import 'share_action_adapter.dart';
import 'share_media_preparation.dart';

String _seconds(Duration value) =>
    (value.inMicroseconds / 1000000).toStringAsFixed(1);
String _fps(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toStringAsFixed(2);

class GifEditorPage extends ConsumerStatefulWidget {
  const GifEditorPage({
    required this.source,
    required this.service,
    required this.fileName,
    required this.share,
    super.key,
  });
  final GifPreparedSource source;
  final GifConversionService service;
  final String fileName;
  final Future<ShareActionOutcome> Function(ShareMediaLease) share;

  @override
  ConsumerState<GifEditorPage> createState() => _GifEditorPageState();
}

class _GifEditorPageState extends ConsumerState<GifEditorPage>
    with WidgetsBindingObserver {
  late final _controller = GifEditorController(
    source: widget.source,
    service: widget.service,
    background: GifBackgroundExecution(
      title: context.t.post.gif_editor.encoding,
      cancelLabel: MaterialLocalizations.of(context).cancelButtonLabel,
    ),
  );
  var _handoff = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The foreground service keeps conversion running through overlays,
    // backgrounding, and screen-off. Engine removal still cancels ownership.
    if (state == AppLifecycleState.detached) {
      _controller.cancel();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_controller.result case final output?) {
      unawaited(FileImage(File(output.path)).evict());
    }
    _controller.dispose();
    super.dispose();
  }

  Future<void> _adjust() async {
    if (_controller.result case final output?) {
      await FileImage(File(output.path)).evict();
    }
    await _controller.adjust();
  }

  Future<void> _export({required bool save}) async {
    final output = _controller.result;
    if (output == null || _handoff) return;
    output.retain();
    setState(() => _handoff = true);
    try {
      String? message;
      if (save) {
        final saved = await ref
            .read(gifSaveServiceProvider)
            .save(output.path, widget.fileName);
        if (mounted && saved) message = context.t.post.gif_editor.saved;
      } else {
        final outcome = await widget.share(output);
        if (mounted && outcome == ShareActionOutcome.unavailable) {
          message = context.t.post.action.share_unsupported_format;
        }
        if (mounted && outcome == ShareActionOutcome.unsupported) {
          message = context.t.post.action.share_storage_error;
        }
      }
      if (mounted && message != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              save
                  ? context.t.post.gif_editor.save_error
                  : context.t.post.action.share_storage_error,
            ),
          ),
        );
      }
    } finally {
      await output.release();
      if (mounted) setState(() => _handoff = false);
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) {
      final t = context.t.post.gif_editor;
      final selected = _controller.selection;
      final (width, height) = selected.dimensions;
      final editing = _controller.phase == GifEditorPhase.editing;
      final estimatedBytes = selected.estimatedBytes;
      final largeEstimate = estimatedBytes > 20 * 1000 * 1000;
      return Scaffold(
        appBar: KurumiAppBar(
          title: Text(context.t.post.action.create_gif),
          actions: [
            if (editing)
              IconButton(
                tooltip: t.reset,
                icon: const Icon(Icons.restart_alt),
                onPressed: () => _controller.update(
                  GifEditorSelection.initial(
                    widget.source.metadata,
                    widget.source.lease.mimeType,
                  ),
                ),
              ),
          ],
        ),
        body: SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            tickMarkShape: const _GifSliderStepShape(),
            activeTickMarkColor: Theme.of(
              context,
            ).colorScheme.onPrimary.withValues(alpha: .35),
            inactiveTickMarkColor: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: .25),
          ),
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) => Column(
                children: [
                  SizedBox(
                    key: const ValueKey('gif-preview'),
                    height: (constraints.maxHeight * .35).clamp(80, 220),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Offstage(
                            offstage:
                                _controller.phase == GifEditorPhase.preview,
                            child: _GifVideoPreview(
                              source: widget.source,
                              selection: selected,
                              enabled: editing,
                            ),
                          ),
                          if (_controller.phase == GifEditorPhase.preview)
                            _GifOutputPreview(
                              key: ValueKey(_controller.result!.path),
                              output: _controller.result!,
                            ),
                        ],
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView(
                      key: ValueKey(_controller.phase),
                      padding: const EdgeInsets.all(16),
                      children: [
                        if (_controller.phase == GifEditorPhase.preview) ...[
                          Text(
                            t.ready,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '${((_controller.resultBytes ?? 0) / 1000000).toStringAsFixed(1)} MB',
                          ),
                          Text(
                            t.summary(
                              duration: _seconds(selected.outputDuration),
                              width: width,
                              height: height,
                              sourceFps: _fps(selected.sourceFrameRate),
                              playbackFps: selected.playbackFrameRate,
                              percent: (selected.speed * 100).round(),
                            ),
                          ),
                          const SizedBox(height: 16),
                          IntrinsicHeight(
                            child: Row(
                              key: const ValueKey('gif-result-actions'),
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    key: const ValueKey('gif-adjust'),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                        vertical: 12,
                                      ),
                                    ),
                                    onPressed: _handoff ? null : _adjust,
                                    child: Text(
                                      t.adjust,
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: FilledButton(
                                    key: const ValueKey('gif-save'),
                                    onPressed: _handoff
                                        ? null
                                        : () => _export(save: true),
                                    style: FilledButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                        vertical: 12,
                                      ),
                                    ),
                                    child: Wrap(
                                      alignment: WrapAlignment.center,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      spacing: 6,
                                      runSpacing: 4,
                                      children: [
                                        const Icon(Icons.save_alt, size: 18),
                                        Text(
                                          t.save,
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: FilledButton(
                                    key: const ValueKey('gif-share'),
                                    onPressed: _handoff
                                        ? null
                                        : () => _export(save: false),
                                    style: FilledButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                        vertical: 12,
                                      ),
                                    ),
                                    child: Wrap(
                                      alignment: WrapAlignment.center,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      spacing: 6,
                                      runSpacing: 4,
                                      children: [
                                        const Icon(Icons.share, size: 18),
                                        Text(
                                          t.share,
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_handoff)
                            const Padding(
                              padding: EdgeInsets.all(16),
                              child: LinearProgressIndicator(),
                            ),
                        ] else if (_controller.phase ==
                            GifEditorPhase.converting) ...[
                          Text(switch (_controller.progress?.stage) {
                            GifConversionStage.checking => t.checking,
                            _ => t.encoding,
                          }, style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: 24),
                          LinearProgressIndicator(
                            value: _controller.progress?.fraction,
                          ),
                          const SizedBox(height: 16),
                          Text(t.foreground),
                          const SizedBox(height: 16),
                          OutlinedButton(
                            key: const ValueKey('gif-cancel'),
                            onPressed: _controller.cancel,
                            child: Text(
                              MaterialLocalizations.of(
                                context,
                              ).cancelButtonLabel,
                            ),
                          ),
                        ] else if (_controller.phase ==
                            GifEditorPhase.error) ...[
                          if (_controller.error?.failure ==
                              GifConversionFailure.oversized)
                            Text(
                              t.too_large_title,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          const SizedBox(height: 12),
                          Text(
                            _controller.error?.failure ==
                                    GifConversionFailure.oversized
                                ? t.too_large_body
                                : gifErrorMessage(context, _controller.error!),
                          ),
                          Text(t.selection_kept),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: _controller.retrySmaller,
                            child: Text(t.smaller),
                          ),
                          OutlinedButton(
                            onPressed: _adjust,
                            child: Text(t.adjust),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: Text(t.back_to_share),
                          ),
                        ] else ...[
                          Text(t.trim_hint),
                          const SizedBox(height: 8),
                          _GifTrimTimeline(
                            selection: selected,
                            timeline: widget.source.timeline,
                            onChanged: _controller.update,
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 16,
                            runSpacing: 4,
                            children: [
                              Text(
                                '${_seconds(selected.start)} s → ${_seconds(selected.end)} s',
                              ),
                              Text(
                                t.selected(
                                  seconds: _seconds(selected.duration),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Text(
                            t.size,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Wrap(
                            spacing: 8,
                            children: [
                              for (final resolution in selected.resolutions)
                                ChoiceChip(
                                  key: ValueKey(
                                    'gif-size-${resolution.longestEdge ?? 'original'}',
                                  ),
                                  selected: selected.resolution == resolution,
                                  label: Text(
                                    resolution.longestEdge == null
                                        ? t.original
                                        : '${resolution.longestEdge}',
                                  ),
                                  onSelected: (_) => _controller.update(
                                    selected.copyWith(resolution: resolution),
                                  ),
                                ),
                            ],
                          ),
                          Text(t.dimensions(width: width, height: height)),
                          const SizedBox(height: 20),
                          Text(
                            t.frames,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            _fps(selected.sourceFrameRate) ==
                                    _fps(selected.source.frameRate!)
                                ? t.original_fps(
                                    value: _fps(selected.sourceFrameRate),
                                  )
                                : t.fps(value: _fps(selected.sourceFrameRate)),
                          ),
                          Slider(
                            key: const ValueKey('gif-source-fps'),
                            max: (selected.sourceFrameRates.length - 1)
                                .toDouble()
                                .clamp(
                                  1,
                                  double.infinity,
                                ),
                            divisions: selected.sourceFrameRates.length > 1
                                ? selected.sourceFrameRates.length - 1
                                : null,
                            value: selected.sourceFrameRates
                                .indexOf(selected.sourceFrameRate)
                                .toDouble(),
                            label: t.fps(value: _fps(selected.sourceFrameRate)),
                            onChanged: selected.sourceFrameRates.length < 2
                                ? null
                                : (value) => _controller.update(
                                    selected.copyWith(
                                      sourceFrameRate: selected
                                          .sourceFrameRates[value.round()],
                                    ),
                                  ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            t.speed,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            t.playback(
                              fps: selected.playbackFrameRate,
                              percent: (selected.speed * 100).round(),
                            ),
                          ),
                          Slider(
                            key: const ValueKey('gif-speed'),
                            max: (selected.speedChoices.length - 1).toDouble(),
                            divisions: selected.speedChoices.length - 1,
                            value: selected.speedIndex.toDouble(),
                            label: '${(selected.speed * 100).round()}%',
                            onChanged: (value) => _controller.update(
                              selected.copyWith(
                                speedPreset:
                                    selected.speedChoices[value.round()].ratio,
                              ),
                            ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${(selected.speedChoices.first.frameRate / selected.sourceFrameRate * 100).round()}%',
                              ),
                              Text(
                                '${(selected.speedChoices.last.frameRate / selected.sourceFrameRate * 100).round()}%',
                              ),
                            ],
                          ),
                          Text(
                            t.duration_change(
                              source: _seconds(selected.duration),
                              gif: _seconds(selected.outputDuration),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        bottomNavigationBar: editing
            ? SafeArea(
                top: false,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    16,
                    16,
                    16 + MediaQuery.viewInsetsOf(context).bottom,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text.rich(
                        key: const ValueKey('gif-estimated-size'),
                        TextSpan(
                          text: estimatedBytes < 1000000
                              ? t.estimate_small
                              : t.estimate(
                                  megabytes: (estimatedBytes / 1000000).round(),
                                ),
                          children: [
                            if (largeEstimate)
                              WidgetSpan(
                                alignment: PlaceholderAlignment.middle,
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 6),
                                  child: Icon(
                                    Icons.warning_amber_rounded,
                                    size: 18,
                                    color: Colors.amber,
                                    semanticLabel: context.t.generic.warning,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        style: largeEstimate
                            ? const TextStyle(color: Colors.amber)
                            : null,
                      ),
                      if (!selected.canCreate) Text(t.invalid_selection),
                      const SizedBox(height: 8),
                      FilledButton(
                        key: const ValueKey('gif-convert'),
                        onPressed: selected.canCreate
                            ? _controller.create
                            : null,
                        child: Text(context.t.post.action.create_gif),
                      ),
                    ],
                  ),
                ),
              )
            : null,
      );
    },
  );
}

class _GifSliderStepShape extends SliderTickMarkShape {
  const _GifSliderStepShape();

  @override
  Size getPreferredSize({
    required SliderThemeData sliderTheme,
    required bool isEnabled,
  }) => const Size(.5, 6);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required Offset thumbCenter,
    required bool isEnabled,
    required TextDirection textDirection,
  }) {
    final active = textDirection == TextDirection.ltr
        ? center.dx <= thumbCenter.dx
        : center.dx >= thumbCenter.dx;
    final color = active
        ? sliderTheme.activeTickMarkColor
        : sliderTheme.inactiveTickMarkColor;
    if (color == null) return;
    context.canvas.drawLine(
      center.translate(0, -3),
      center.translate(0, 3),
      Paint()
        ..color = color.withValues(alpha: color.a * enableAnimation.value)
        ..strokeWidth = 1,
    );
  }
}

/// Keeps the file alive through image-codec loading even if the route closes
/// before its first frame arrives. Subsequent animation frames use loaded bytes.
class _GifOutputPreview extends StatefulWidget {
  const _GifOutputPreview({required this.output, super.key});
  final ShareMediaLease output;
  @override
  State<_GifOutputPreview> createState() => _GifOutputPreviewState();
}

class _GifOutputPreviewState extends State<_GifOutputPreview> {
  late final _image = FileImage(File(widget.output.path));
  final _loaded = Completer<void>();
  ImageStream? _stream;
  late final _listener = ImageStreamListener(
    (info, _) {
      if (!_loaded.isCompleted) _loaded.complete();
      info.dispose();
    },
    onError: (error, stack) {
      if (!_loaded.isCompleted) _loaded.complete();
    },
  );

  @override
  void initState() {
    super.initState();
    widget.output.retain();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_stream != null) return;
    _stream = _image.resolve(createLocalImageConfiguration(context));
    _stream!.addListener(_listener);
  }

  @override
  void dispose() {
    unawaited(_release());
    super.dispose();
  }

  Future<void> _release() async {
    await _loaded.future;
    _stream?.removeListener(_listener);
    try {
      await _image.evict();
    } finally {
      await widget.output.release();
    }
  }

  @override
  Widget build(BuildContext context) => Image(
    image: _image,
    fit: BoxFit.contain,
    errorBuilder: (_, _, _) =>
        Center(child: Text(context.t.post.gif_editor.preview_unavailable)),
  );
}

class _GifTrimTimeline extends StatefulWidget {
  const _GifTrimTimeline({
    required this.selection,
    required this.timeline,
    required this.onChanged,
  });
  final GifEditorSelection selection;
  final ShareMediaLease? timeline;
  final ValueChanged<GifEditorSelection> onChanged;
  @override
  State<_GifTrimTimeline> createState() => _GifTrimTimelineState();
}

class _GifTrimTimelineState extends State<_GifTrimTimeline> {
  late GifEditorSelection _dragSelection;
  late double _dragDistance;
  Widget _draggable({
    required Widget child,
    required String label,
    required int edge,
    required double width,
  }) => Semantics(
    label: label,
    value: _timelineValue(widget.selection, edge),
    increasedValue: _timelineValue(
      _next(widget.selection, const Duration(milliseconds: 100), edge),
      edge,
    ),
    decreasedValue: _timelineValue(
      _next(widget.selection, const Duration(milliseconds: -100), edge),
      edge,
    ),
    onIncrease: () =>
        _move(widget.selection, const Duration(milliseconds: 100), edge),
    onDecrease: () =>
        _move(widget.selection, const Duration(milliseconds: -100), edge),
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: (_) {
        _dragSelection = widget.selection;
        _dragDistance = 0;
      },
      onHorizontalDragUpdate: (details) {
        _dragDistance += details.delta.dx;
        _move(
          _dragSelection,
          Duration(
            microseconds:
                (_dragDistance /
                        width *
                        widget.selection.sourceDuration.inMicroseconds)
                    .round(),
          ),
          edge,
        );
      },
      child: child,
    ),
  );

  String _timelineValue(GifEditorSelection selected, int edge) =>
      '${_seconds(edge == 1 ? selected.end : selected.start)} s';
  void _move(GifEditorSelection selected, Duration delta, int edge) =>
      widget.onChanged(_next(selected, delta, edge));
  GifEditorSelection _next(
    GifEditorSelection selected,
    Duration delta,
    int edge,
  ) => switch (edge) {
    -1 => selected.moveStart(selected.start + delta),
    1 => selected.moveEnd(selected.end + delta),
    _ => selected.moveWindow(selected.start + delta),
  };

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth - 44;
      final selected = widget.selection;
      final left =
          selected.start.inMicroseconds /
              selected.sourceDuration.inMicroseconds *
              width +
          22;
      final right =
          selected.end.inMicroseconds /
              selected.sourceDuration.inMicroseconds *
              width +
          22;
      final color = Theme.of(context).colorScheme.primary;
      final t = context.t.post.gif_editor;
      return SizedBox(
        height: 68,
        child: Stack(
          children: [
            Positioned(
              left: 22,
              right: 22,
              top: 6,
              bottom: 6,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: widget.timeline == null
                    ? ColoredBox(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                      )
                    : Image.file(
                        File(widget.timeline!.path),
                        fit: BoxFit.fill,
                        errorBuilder: (_, _, _) => ColoredBox(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                        ),
                      ),
              ),
            ),
            Positioned(
              left: left,
              width: right - left,
              top: 4,
              bottom: 4,
              child: _draggable(
                label: t.move_window,
                edge: 0,
                width: width,
                child: Container(
                  key: const ValueKey('gif-trim-window'),
                  decoration: BoxDecoration(
                    border: Border.all(color: color, width: 3),
                    color: color.withValues(alpha: .12),
                  ),
                ),
              ),
            ),
            for (final edge in [-1, 1])
              Positioned(
                left: (edge == -1 ? left : right) - 22,
                width: 44,
                top: 0,
                bottom: 0,
                child: _draggable(
                  label: edge == -1 ? t.clip_start : t.clip_end,
                  edge: edge,
                  width: width,
                  child: Center(
                    child: Container(
                      key: ValueKey('gif-trim-$edge'),
                      width: 12,
                      height: 60,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(Icons.drag_indicator, size: 12),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
}

class _GifVideoPreview extends StatefulWidget {
  const _GifVideoPreview({
    required this.source,
    required this.selection,
    required this.enabled,
  });
  final GifPreparedSource source;
  final GifEditorSelection selection;
  final bool enabled;
  @override
  State<_GifVideoPreview> createState() => _GifVideoPreviewState();
}

class _GifVideoPreviewState extends State<_GifVideoPreview>
    with WidgetsBindingObserver {
  late final _video = VideoPlayerController.file(
    File(widget.source.lease.path),
  );
  var _ready = false;
  var _unavailable = false;
  var _creationFailed = false;
  var _seeking = false;
  late final Future<void> _initialization;
  @override
  void initState() {
    super.initState();
    widget.source.lease.retain();
    WidgetsBinding.instance.addObserver(this);
    _video.addListener(_loop);
    _initialization = _initialize();
  }

  Future<void> _initialize() async {
    try {
      await _video.initialize();
      if (!mounted) return;
      await _video.setVolume(0);
      await _video.seekTo(widget.selection.start);
      await _video.setPlaybackSpeed(widget.selection.speed);
      if (mounted) setState(() => _ready = true);
    } catch (_) {
      _creationFailed = !_video.value.isInitialized && !_video.value.hasError;
      if (mounted) setState(() => _unavailable = true);
    }
  }

  void _loop() {
    if (!_ready || _seeking || !_video.value.isPlaying) return;
    if (_video.value.position >= widget.selection.end ||
        _video.value.position < widget.selection.start) {
      _seeking = true;
      unawaited(
        _video
            .seekTo(widget.selection.start)
            .whenComplete(() => _seeking = false),
      );
    }
  }

  @override
  void didUpdateWidget(_GifVideoPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_ready) {
      if (!widget.enabled) unawaited(_video.pause());
      if (oldWidget.selection.start != widget.selection.start ||
          oldWidget.selection.end != widget.selection.end ||
          oldWidget.selection.speed != widget.selection.speed) {
        unawaited(_video.setPlaybackSpeed(widget.selection.speed));
        unawaited(_video.seekTo(widget.selection.start));
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && _ready) unawaited(_video.pause());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _video.removeListener(_loop);
    unawaited(_disposeVideo());
    super.dispose();
  }

  Future<void> _disposeVideo() async {
    try {
      await _initialization;
      // A platform creation failure leaves video_player's creation completer
      // unresolved. Decoder errors arrive through value.hasError after creation
      // and still require disposal before releasing the source file.
      if (!_creationFailed) {
        await _video.dispose();
      }
    } finally {
      await widget.source.lease.release();
    }
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 220,
    child: _unavailable
        ? Center(child: Text(context.t.post.gif_editor.preview_unavailable))
        : !_ready
        ? const Center(child: CircularProgressIndicator())
        : Stack(
            alignment: Alignment.center,
            children: [
              AspectRatio(
                aspectRatio: _video.value.aspectRatio,
                child: VideoPlayer(_video),
              ),
              ValueListenableBuilder(
                valueListenable: _video,
                builder: (context, value, _) => IconButton.filled(
                  tooltip: value.isPlaying
                      ? context.t.post.gif_editor.pause
                      : context.t.post.gif_editor.play,
                  onPressed: widget.enabled
                      ? () => value.isPlaying ? _video.pause() : _video.play()
                      : null,
                  icon: Icon(value.isPlaying ? Icons.pause : Icons.play_arrow),
                ),
              ),
            ],
          ),
  );
}
