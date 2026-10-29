import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

import '../../../posts/details_parts/src/toolbars/customizable_post_toolbar.dart';
import '../../../widgets/adaptive_button_row.dart';
import 'viewer_toolbar_action_labels.dart';

/// Edits a draft only. The route owns persistence, Apply, cancellation and Reset.
/// The preview uses inert actions and the same renderer as the real viewer.
class ViewerToolbarEditor extends StatefulWidget {
  const ViewerToolbarEditor({required this.layout, required this.onChanged, super.key});
  final ViewerToolbarLayout layout;
  final ValueChanged<ViewerToolbarLayout> onChanged;

  @override
  State<ViewerToolbarEditor> createState() => _ViewerToolbarEditorState();
}

class _ViewerToolbarEditorState extends State<ViewerToolbarEditor> {
  ViewerToolbarAction? _selected;
  ViewerToolbarLayout get layout => widget.layout;

  void _select(ViewerToolbarAction id) => setState(() => _selected = id);

  void _move(ViewerToolbarAction id, bool toolbar, int index) {
    _select(id);
    widget.onChanged(layout.move(id, toToolbar: toolbar, index: index));
  }

  void _drop(ViewerToolbarAction id, bool toolbar, int index) {
    if (toolbar && !layout.toolbar.contains(id) &&
        layout.toolbar.length == ViewerToolbarLayout.maxToolbarActions) {
      if (index >= layout.toolbar.length) return;
      _select(id);
      widget.onChanged(layout.replace(layout.toolbar[index], withAction: id));
    } else {
      _move(id, toolbar, index);
    }
  }

  Future<void> _transfer(ViewerToolbarAction id) async {
    if (layout.toolbar.contains(id)) {
      _move(id, false, 0);
      return;
    }
    if (layout.toolbar.length < ViewerToolbarLayout.maxToolbarActions) {
      _move(id, true, layout.toolbar.length);
      return;
    }
    // A full row never silently evicts another action. Choose the exact slot.
    final before = layout;
    final target = await showDialog<ViewerToolbarAction>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(context.t.post.detail.widgets.toolbar),
        children: [for (final slot in before.toolbar)
          SimpleDialogOption(
            key: ValueKey('replace-toolbar-${slot.name}'),
            onPressed: () => Navigator.pop(context, slot),
            child: Row(children: [
              Icon(viewerToolbarActionIcon(slot)),
              const SizedBox(width: 12),
              Expanded(child: Text(viewerToolbarActionLabel(context, slot))),
            ]),
          ),
        ],
      ),
    );
    if (!mounted || target == null || layout != before) return;
    widget.onChanged(layout.replace(target, withAction: id));
  }

  Widget _dropZone({
    required Key key,
    required bool toolbar,
    required int index,
    required Widget child,
  }) => DragTarget<ViewerToolbarAction>(
    key: key,
    onWillAcceptWithDetails: (details) => !toolbar ||
        layout.toolbar.contains(details.data) ||
        layout.toolbar.length < ViewerToolbarLayout.maxToolbarActions ||
        index < layout.toolbar.length,
    onAcceptWithDetails: (details) => _drop(details.data, toolbar, index),
    builder: (context, candidates, rejected) => DecoratedBox(
      decoration: BoxDecoration(
        color: candidates.isEmpty ? Colors.transparent : Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: child,
    ),
  );

  Widget _draggable(ViewerToolbarAction id, Widget child) => LongPressDraggable<ViewerToolbarAction>(
    data: id,
    maxSimultaneousDrags: 1,
    onDragStarted: () => _select(id),
    feedback: Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(viewerToolbarActionIcon(id)),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180),
            child: Text(viewerToolbarActionLabel(context, id)),
          ),
        ]),
      ),
    ),
    childWhenDragging: Opacity(opacity: .35, child: child),
    child: child,
  );

  @override
  Widget build(BuildContext context) {
    final theme = Kurumi.themeOf(context);
    final selected = _selected;
    final inToolbar = selected != null && layout.toolbar.contains(selected);
    final entries = inToolbar ? layout.toolbar : layout.more;
    final index = selected == null ? -1 : entries.indexOf(selected);
    final strings = WidgetsLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // The fixed utility is included to demonstrate that More stays reachable.
        Material(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: ConfiguredPostToolbar(layout: layout, buttons: [
              for (final id in ViewerToolbarAction.values)
                ViewerToolbarSimpleButtonData(
                  action: id,
                  icon: viewerToolbarActionIcon(id),
                  title: viewerToolbarActionLabel(context, id),
                  onPressed: () => _select(id),
                ),
              SimpleButtonData(icon: Icons.travel_explore,
                title: context.t.post.cross_profile.action, onPressed: () {}),
              SimpleButtonData(icon: Icons.settings, title: context.t.settings.settings,
                onPressed: () {}),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        Text(context.t.booru.appearance.image_viewer_layout.rearrange_tip,
          style: theme.textTheme.bodySmall),
        const SizedBox(height: 12),
        Text(context.t.post.detail.widgets.toolbar, style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        // Configuration slots stay editable even when the preview overflows.
        // Horizontal scrolling here avoids shrinking touch targets on small screens.
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(textDirection: TextDirection.ltr, children: [
            for (final (i, id) in layout.toolbar.indexed)
              _dropZone(
                key: ValueKey('drop-toolbar-${id.name}'), toolbar: true, index: i,
                child: _draggable(id, Padding(
                  padding: const EdgeInsets.all(2),
                  child: SizedBox(width: 56, child: Column(children: [
                    IconButton(
                      key: ValueKey('edit-toolbar-${id.name}'),
                      tooltip: viewerToolbarActionLabel(context, id),
                      isSelected: selected == id,
                      onPressed: () => _select(id),
                      icon: Icon(viewerToolbarActionIcon(id)),
                    ),
                    Text(viewerToolbarActionLabel(context, id),
                      textAlign: TextAlign.center, maxLines: 2,
                      overflow: TextOverflow.ellipsis, style: theme.textTheme.labelSmall),
                  ])),
                )),
              ),
            _dropZone(
              key: const Key('toolbar-append-drop'), toolbar: true, index: layout.toolbar.length,
              child: SizedBox(width: 48, height: 60,
                child: Icon(layout.toolbar.length < ViewerToolbarLayout.maxToolbarActions
                  ? Icons.add : Icons.more_horiz)),
            ),
          ]),
        ),
        const SizedBox(height: 8),
        if (selected != null) ...[
          Text(viewerToolbarActionLabel(context, selected),
            key: const Key('toolbar-selected-label'), style: theme.textTheme.titleSmall),
          Wrap(spacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
            IconButton(
              key: const Key('toolbar-move-back'),
              tooltip: inToolbar ? strings.reorderItemLeft : strings.reorderItemUp,
              onPressed: index > 0 ? () => _move(selected, inToolbar, index - 1) : null,
              icon: Icon(inToolbar ? Icons.arrow_back : Icons.arrow_upward),
            ),
            IconButton(
              key: const Key('toolbar-move-forward'),
              tooltip: inToolbar ? strings.reorderItemRight : strings.reorderItemDown,
              onPressed: index >= 0 && index < entries.length - 1
                ? () => _move(selected, inToolbar, index + 2) : null,
              icon: Icon(inToolbar ? Icons.arrow_forward : Icons.arrow_downward),
            ),
            TextButton.icon(
              key: const Key('toolbar-transfer'),
              onPressed: () => _transfer(selected),
              icon: Icon(inToolbar ? Icons.more_horiz : Icons.view_week_outlined),
              label: Text(inToolbar ? context.t.generic.action.more : context.t.post.detail.widgets.toolbar),
            ),
          ]),
        ],
        _dropZone(
          key: const Key('toolbar-more-drop'), toolbar: false, index: 0,
          child: Padding(padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(children: [
              const Icon(Icons.more_horiz), const SizedBox(width: 8),
              Text(context.t.generic.action.more, style: theme.textTheme.titleSmall),
            ])),
        ),
        for (final (i, id) in layout.more.indexed)
          _dropZone(
            key: ValueKey('drop-more-${id.name}'), toolbar: false, index: i,
            child: _draggable(id, ListTile(
              key: ValueKey('edit-more-${id.name}'),
              selected: selected == id,
              leading: Icon(viewerToolbarActionIcon(id)),
              title: Text(viewerToolbarActionLabel(context, id)),
              trailing: const Icon(Icons.drag_indicator),
              onTap: () => _select(id),
            )),
          ),
        _dropZone(
          key: const Key('toolbar-more-end-drop'), toolbar: false, index: layout.more.length,
          child: const SizedBox(height: 48, width: double.infinity),
        ),
      ]),
    );
  }
}
