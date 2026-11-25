import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

import '../../../posts/details_parts/src/toolbars/customizable_post_toolbar.dart';
import '../../../widgets/adaptive_button_row.dart';
import 'viewer_toolbar_action_labels.dart';

/// The preview and both editable sections share a single scrollable list.
class ViewerToolbarEditor extends StatelessWidget {
  const ViewerToolbarEditor({
    required this.layout,
    required this.availableActions,
    required this.onChanged,
    this.footer,
    super.key,
  });

  final ViewerToolbarLayout layout;
  final Set<ViewerToolbarAction> availableActions;
  final ValueChanged<ViewerToolbarLayout> onChanged;
  final Widget? footer;

  void _reorder(ViewerToolbarLayout visible, int from, int to) {
    final separator = visible.toolbar.length;
    if (from == separator || from == to) return;

    final fromToolbar = from < separator;
    final source = fromToolbar ? from : from - separator - 1;
    final action = (fromToolbar ? visible.toolbar : visible.more)[source];
    final remainingToolbarLength = separator - (fromToolbar ? 1 : 0);
    final toToolbar = to <= remainingToolbarLength;
    final destination = toToolbar ? to : to - remainingToolbarLength - 1;

    if (toToolbar &&
        !fromToolbar &&
        separator >= ViewerToolbarLayout.maxToolbarActions) {
      // An insertion before a specific action swaps that slot. An append does
      // not choose an action to displace.
      if (destination < separator) {
        onChanged(
          layout.withAvailableOrder(
            visible.replace(visible.toolbar[destination], withAction: action),
            availableActions,
          ),
        );
      }
      return;
    }

    final index = toToolbar == fromToolbar && destination > source
        ? destination + 1
        : destination;
    onChanged(
      layout.withAvailableOrder(
        visible.move(action, toToolbar: toToolbar, index: index),
        availableActions,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Kurumi.themeOf(context);
    final strings =
        context.t.booru.appearance.image_viewer_layout.toolbar_editor;
    final visible = layout.availableOnly(availableActions);
    final separator = visible.toolbar.length;

    return ReorderableListView.builder(
      padding: const EdgeInsets.all(12),
      buildDefaultDragHandles: false,
      onReorderItem: (from, to) => _reorder(visible, from, to),
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: ConfiguredPostToolbar(
                layout: layout,
                padding: EdgeInsets.zero,
                buttons: [
                  for (final id in availableActions)
                    ViewerToolbarSimpleButtonData(
                      action: id,
                      icon: viewerToolbarActionIcon(id),
                      title: viewerToolbarActionLabel(context, id),
                      onPressed: () {},
                    ),
                  SimpleButtonData(
                    icon: Icons.travel_explore,
                    title: context.t.post.cross_profile.action,
                    onPressed: () {},
                  ),
                  SimpleButtonData(
                    icon: Icons.settings,
                    title: context.t.settings.settings,
                    onPressed: () {},
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            separator >= ViewerToolbarLayout.maxToolbarActions
                ? strings.drag_full
                : strings.drag,
            style: theme.textTheme.bodySmall,
          ),
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Text(
              context.t.post.detail.widgets.toolbar,
              style: theme.textTheme.titleSmall,
            ),
          ),
        ],
      ),
      footer: footer,
      itemCount: visible.toolbar.length + visible.more.length + 1,
      itemBuilder: (context, index) {
        if (index == separator) {
          return Padding(
            key: const ValueKey('toolbar-more-heading'),
            padding: const EdgeInsets.only(top: 16, bottom: 4),
            child: Text(
              context.t.generic.action.more,
              style: theme.textTheme.titleSmall,
            ),
          );
        }
        final id = index < separator
            ? visible.toolbar[index]
            : visible.more[index - separator - 1];
        return ListTile(
          key: ValueKey(id),
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          leading: Icon(viewerToolbarActionIcon(id)),
          title: Text(viewerToolbarActionLabel(context, id)),
          trailing: ReorderableDragStartListener(
            key: ValueKey('toolbar-drag-${id.name}'),
            index: index,
            child: const SizedBox(
              width: 48,
              height: 48,
              child: ColoredBox(
                color: Colors.transparent,
                child: Icon(Icons.drag_indicator),
              ),
            ),
          ),
        );
      },
    );
  }
}
