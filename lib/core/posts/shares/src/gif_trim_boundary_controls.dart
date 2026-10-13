import 'dart:math' as math;

import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

import 'gif_editor_selection.dart';

class GifTrimBoundaryControls extends StatelessWidget {
  const GifTrimBoundaryControls({
    required this.selection,
    required this.position,
    required this.onChanged,
    super.key,
  });

  final GifEditorSelection selection;
  final Duration position;
  final ValueChanged<GifEditorSelection> onChanged;

  Widget _group({
    required BuildContext context,
    required bool start,
    required String label,
    required String backwardHint,
    required String forwardHint,
    required String setHint,
  }) {
    final previous = start ? selection.stepStart(-1) : selection.stepEnd(-1);
    final next = start ? selection.stepStart(1) : selection.stepEnd(1);
    bool changed(GifEditorSelection value) =>
        value.start != selection.start || value.end != selection.end;
    final edge = start ? 'start' : 'end';
    final buttonStyle = IconButton.styleFrom(
      minimumSize: const Size(48, 48),
      visualDensity: VisualDensity.standard,
    );
    return Semantics(
      container: true,
      label: label,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: IconButton(
                style: buttonStyle,
                key: ValueKey('gif-trim-$edge-back'),
                tooltip: backwardHint,
                onPressed: changed(previous) ? () => onChanged(previous) : null,
                icon: const Icon(Icons.chevron_left),
              ),
            ),
            Expanded(
              child: IconButton(
                style: buttonStyle,
                key: ValueKey('gif-trim-$edge-forward'),
                tooltip: forwardHint,
                onPressed: changed(next) ? () => onChanged(next) : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ),
            Expanded(
              child: IconButton(
                style: buttonStyle,
                key: ValueKey('gif-trim-$edge-here'),
                tooltip: setHint,
                onPressed: () => onChanged(
                  start
                      ? selection.setStartAt(position)
                      : selection.setEndAt(position),
                ),
                icon: const Icon(Icons.my_location),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t.gif_trim;
    final labels = context.t.post.gif_editor;
    return LayoutBuilder(
      builder: (context, constraints) {
        final gap = constraints.maxWidth >= 296 ? 8.0 : 0.0;
        // Preserve six 48px targets in one row. Only extremely narrow views
        // need horizontal scrolling; enlarged labels never wrap the buttons.
        final width = math.max(constraints.maxWidth, 288 + gap);
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: width,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        labels.clip_start,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    SizedBox(width: gap),
                    Expanded(
                      child: Text(labels.clip_end, textAlign: TextAlign.center),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: _group(
                        context: context,
                        start: true,
                        label: labels.clip_start,
                        backwardHint: t.start_frame_back,
                        forwardHint: t.start_frame_forward,
                        setHint: t.start_here,
                      ),
                    ),
                    SizedBox(width: gap),
                    Expanded(
                      child: _group(
                        context: context,
                        start: false,
                        label: labels.clip_end,
                        backwardHint: t.end_frame_back,
                        forwardHint: t.end_frame_forward,
                        setHint: t.end_here,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
