import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

import 'gif_editor_controller.dart';
import 'gif_loop_refinement.dart';

/// Uses the existing editor's trim state; no second selection workflow.
class GifLoopEditorActions extends StatelessWidget {
  const GifLoopEditorActions({required this.controller, super.key});
  final GifEditorController controller;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final t = context.t.post.gif_editor;
      final result = controller.loopResult;
      final busy = controller.isRefining;
      if (!controller.showRefineLoop && !busy && !controller.canUndoRefinement) {
        return const SizedBox.shrink();
      }
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (controller.showRefineLoop)
                  OutlinedButton.icon(
                    key: const ValueKey('gif-refine-loop'),
                    onPressed: busy || !controller.selection.canCreate
                        ? null : controller.refineLoop,
                    icon: const Icon(Icons.auto_fix_high, size: 18),
                    label: Text(t.refine_loop),
                  ),
                if (busy)
                  TextButton(
                    key: const ValueKey('gif-refine-cancel'),
                    onPressed: controller.cancelRefinement,
                    child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
                  ),
                if (controller.canUndoRefinement)
                  TextButton.icon(
                    key: const ValueKey('gif-refine-undo'),
                    onPressed: busy ? null : controller.undoRefinement,
                    icon: const Icon(Icons.undo, size: 18),
                    label: Text(t.undo_refinement),
                  ),
              ],
            ),
            if (busy) ...[
              LinearProgressIndicator(semanticsLabel: t.refining_loop),
              Text(t.refining_loop),
            ] else if (result != null)
              Semantics(
                liveRegion: true,
                child: Text(switch (result.kind) {
                  GifLoopMatchKind.repeatedSequence => t.loop_refined,
                  GifLoopMatchKind.seamOnly => t.loop_seam_hint,
                  GifLoopMatchKind.none => t.loop_no_match,
                }),
              ),
          ],
        ),
      );
    },
  );
}
