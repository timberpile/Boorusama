import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';
import 'package:kurumi/kurumi.dart';

import 'gif_conversion_service.dart';
import 'gif_editor_controller.dart';
import 'gif_editor_selection.dart';
import 'gif_loop_editor_actions.dart';
import 'gif_loop_refinement_service.dart';
import 'gif_loop_video_preview.dart';
import 'gif_preview_frame.dart';
import 'gif_trim_navigation.dart';
import 'gif_trim_boundary_controls.dart';
import 'gif_trim_navigator.dart';

/// Full-screen subdialog: only Apply returns trim boundaries to the exporter.
/// The exporter owns navigation so Adjust/reopening does not reset its zoom.
class GifTrimEditor extends StatefulWidget {
  const GifTrimEditor({
    required this.source,
    required this.service,
    required this.selection,
    required this.navigation,
    this.refiner,
    super.key,
  });
  final GifPreparedSource source;
  final GifConversionService service;
  final GifEditorSelection selection;
  final GifTrimNavigation navigation;
  final GifLoopRefiner? refiner;

  @override
  State<GifTrimEditor> createState() => _GifTrimEditorState();
}

class _GifTrimEditorState extends State<GifTrimEditor> {
  late final _draft = GifEditorController(
    source: widget.source,
    service: widget.service,
    loopRefiner: widget.refiner,
  )..update(widget.selection);
  late final _position = ValueNotifier(widget.selection.start);
  final _seekRequests = ValueNotifier<(int, Duration)>((0, Duration.zero));
  var _seekId = 0;

  @override
  void initState() {
    super.initState();
    widget.navigation.initialize(widget.selection.start, widget.selection.end);
  }

  void _seek(Duration time) {
    final duration = widget.selection.sourceDuration;
    final bounded = Duration(
      microseconds: time.inMicroseconds.clamp(0, duration.inMicroseconds),
    );
    final selected = _draft.selection;
    if (bounded < selected.start || bounded >= selected.end) {
      widget.navigation.setSourceMode(true);
    }
    _position.value = bounded;
    // Apply mode/range changes before delivering the seek to the preview.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _seekRequests.value = (++_seekId, bounded);
    });
  }

  @override
  void dispose() {
    _draft.dispose();
    _position.dispose();
    _seekRequests.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([_draft, widget.navigation]),
    builder: (context, _) {
      final selected = _draft.selection;
      final view = widget.navigation;
      final t = context.t.gif_trim;
      return Scaffold(
        appBar: AppBar(
          title: Text(t.title),
          leading: IconButton(
            key: const ValueKey('gif-trim-cancel'),
            tooltip: MaterialLocalizations.of(context).cancelButtonLabel,
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
          ),
        ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => Column(
              children: [
                GifPreviewFrame(
                  aspectRatio: selected.displayAspectRatio,
                  maxHeight: (constraints.maxHeight * .32).clamp(80, 220),
                  child: GifLoopVideoPreview(
                    source: widget.source,
                    selection: selected,
                    enabled: true,
                    prepareLoop: !_draft.isRefining,
                    position: _position,
                    sourceMode: view.sourceMode,
                    previewSpeed: view.previewSpeed,
                    seekRequests: _seekRequests,
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          ChoiceChip(
                            key: const ValueKey('gif-trim-source'),
                            label: Text(t.source),
                            showCheckmark: false,
                            selected: view.sourceMode,
                            onSelected: (_) => view.setSourceMode(true),
                          ),
                          ChoiceChip(
                            key: const ValueKey('gif-trim-loop'),
                            label: Text(t.loop),
                            showCheckmark: false,
                            selected: !view.sourceMode,
                            onSelected: (_) => view.setSourceMode(false),
                          ),
                          Tooltip(
                            message:
                                '${t.preview_speed}\n${t.preview_speed_hint}',
                            child: Semantics(
                              label: t.preview_speed,
                              child: KurumiOptionDropDownButton<double>(
                                key: const ValueKey('gif-trim-speed'),
                                value: view.previewSpeed,
                                selectedItemFlexible: false,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 12,
                                ),
                                selectedItemBuilder: (speed) => Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.speed, size: 20),
                                    const SizedBox(width: 6),
                                    Text('${(speed * 100).round()}%'),
                                  ],
                                ),
                                onChanged: (speed) {
                                  if (speed != null) {
                                    view.setPreviewSpeed(speed);
                                  }
                                },
                                items: [
                                  for (final speed in const [.25, .5, .75, 1.0])
                                    DropdownMenuItem(
                                      value: speed,
                                      child: Text(
                                        '${(speed * 100).round()}%',
                                        key: ValueKey('gif-trim-speed-$speed'),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      GifTrimNavigator(
                        selection: selected,
                        navigation: view,
                        position: _position,
                        onChanged: _draft.update,
                        onSeek: _seek,
                      ),
                      const SizedBox(height: 8),
                      ValueListenableBuilder<Duration>(
                        valueListenable: _position,
                        builder: (context, position, _) => Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              '${context.t.post.gif_editor.timeline_position}: ${gifTrimTime(position)}',
                            ),
                            GifTrimBoundaryControls(
                              selection: selected,
                              position: position,
                              onChanged: _draft.update,
                            ),
                          ],
                        ),
                      ),
                      Wrap(
                        spacing: 8,
                        children: [
                          Text(
                            '${gifTrimTime(selected.start)} → ${gifTrimTime(selected.end)}',
                          ),
                          Text(
                            context.t.post.gif_editor.selected(
                              seconds:
                                  (selected.duration.inMicroseconds / 1000000)
                                      .toStringAsFixed(3),
                            ),
                          ),
                        ],
                      ),
                      GifLoopEditorActions(controller: _draft),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton(
              key: const ValueKey('gif-trim-apply'),
              onPressed: _draft.isRefining
                  ? null
                  : () {
                      view.focus(selected.start, selected.end);
                      Navigator.of(context).pop((selected.start, selected.end));
                    },
              child: Text(t.apply),
            ),
          ),
        ),
      );
    },
  );
}
