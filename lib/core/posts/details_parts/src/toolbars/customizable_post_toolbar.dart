import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

import '../../../../settings/src/providers/settings_provider.dart';
import '../../../../settings/src/types/viewer_toolbar_layout.dart';
import '../../../../widgets/adaptive_button_row.dart';
import '../../../../widgets/booru_menu_button_row.dart';

export '../../../../settings/src/types/viewer_toolbar_layout.dart';

/// Viewer-only identity and menu presentation; other adaptive rows are unchanged.
class ViewerToolbarButtonData extends ButtonData {
  const ViewerToolbarButtonData({
    required this.action,
    required super.widget,
    required super.title,
    super.icon,
    super.onTap,
    super.enabled,
    super.required,
    super.placement,
    this.menuBuilder,
  });

  final ViewerToolbarAction action;

  /// Reuses real action controls, including loading and quality submenus.
  final Widget Function(BuildContext, VoidCallback closeMenu)? menuBuilder;
}

class ViewerToolbarSimpleButtonData extends ViewerToolbarButtonData {
  ViewerToolbarSimpleButtonData({
    required super.action,
    required IconData icon,
    required super.title,
    required VoidCallback onPressed,
    super.placement,
    super.required,
  }) : super(
         widget: IconButton(
           tooltip: title,
           icon: Icon(icon),
           onPressed: onPressed,
         ),
         icon: Icon(icon),
         onTap: onPressed,
       );
}

final viewerToolbarLayoutProvider = Provider<ViewerToolbarLayout?>(
  (ref) => ref.watch(settingsProvider.select((s) => s.viewerToolbarLayout)),
  dependencies: [settingsProvider],
);

class CustomizablePostToolbar extends ConsumerWidget {
  const CustomizablePostToolbar({
    required this.buttons,
    this.maxVisibleButtons,
    super.key,
  });

  final List<ButtonData> buttons;
  final int? maxVisibleButtons;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layout = ref.watch(viewerToolbarLayoutProvider);
    // Existing installations retain the engine's native layout until opting in.
    if (layout == null) {
      return BooruMenuButtonRow(
        crossAxisAlignment: CrossAxisAlignment.start,
        maxVisibleButtons: maxVisibleButtons,
        buttons: buttons,
      );
    }
    return ConfiguredPostToolbar(layout: layout, buttons: buttons);
  }
}

/// Shared with the editor preview. Callers key by post/profile to discard menus
/// belonging to a previous post. Preferences never change while fitting a row.
class ConfiguredPostToolbar extends StatefulWidget {
  const ConfiguredPostToolbar({
    required this.layout,
    required this.buttons,
    super.key,
  });

  final ViewerToolbarLayout layout;
  final List<ButtonData> buttons;

  @override
  State<ConfiguredPostToolbar> createState() => _ConfiguredPostToolbarState();
}

class _ConfiguredPostToolbarState extends State<ConfiguredPostToolbar> {
  final _menu = AnchorController();

  @override
  void didUpdateWidget(ConfiguredPostToolbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final before = [
      for (final b in oldWidget.buttons)
        (b is ViewerToolbarButtonData ? b.action : b.title, b.enabled),
    ];
    final after = [
      for (final b in widget.buttons)
        (b is ViewerToolbarButtonData ? b.action : b.title, b.enabled),
    ];
    if (oldWidget.layout != widget.layout || !listEquals(before, after)) {
      _menu.hide();
    }
  }

  @override
  void dispose() {
    _menu.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // An anchor can live above a mixed viewer's per-post provider scope.
    final container = ProviderScope.containerOf(context, listen: false);
    final byAction = {
      for (final button in widget.buttons.whereType<ViewerToolbarButtonData>())
        button.action: button,
    };
    final fixed = widget.buttons
        .where((button) => button is! ViewerToolbarButtonData)
        .toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final projected = widget.layout.project(
            byAction.keys.toSet(),
            capacity: viewerToolbarCapacity(constraints.maxWidth),
          );
          final more = <ButtonData>[
            for (final id in projected.more) byAction[id]!,
            ...fixed,
          ];
          return Row(
            // Physical slots: More stays right; labels retain locale direction.
            textDirection: TextDirection.ltr,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (projected.toolbar.isEmpty)
                const Spacer()
              else
                Expanded(
                  child: Row(
                    textDirection: TextDirection.ltr,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final (index, id) in projected.toolbar.indexed) ...[
                        if (index > 0) const SizedBox(width: 8),
                        Expanded(
                          child: ConstrainedBox(
                            key: ValueKey('viewer-toolbar-${id.name}'),
                            constraints: const BoxConstraints(minHeight: 48),
                            child: Center(
                              heightFactor: 1,
                              child: byAction[id]!.widget,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              SizedBox(width: math.min(8.0, constraints.maxWidth)),
              SizedBox(
                width: math.min(48.0, math.max(0.0, constraints.maxWidth - 8)),
                child: KurumiAnchor(
                  controller: _menu,
                  spacing: 8,
                  overlayBuilder: (context) => UncontrolledProviderScope(
                    container: container,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: math.min(320.0, MediaQuery.sizeOf(context).width),
                        maxHeight: math.max(
                          0.0,
                          MediaQuery.sizeOf(context).height -
                              MediaQuery.viewInsetsOf(context).bottom -
                              MediaQuery.paddingOf(context).vertical - 24,
                        ),
                      ),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (final button in more) _entry(context, button),
                          ],
                        ),
                      ),
                    ),
                  ),
                  child: IconButton(
                    key: const Key('viewer-toolbar-more'),
                    tooltip: context.t.generic.action.more,
                    constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
                    onPressed: more.isEmpty ? null : _menu.toggle,
                    icon: const Icon(Icons.more_horiz),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _entry(BuildContext context, ButtonData button) {
    if (button is ViewerToolbarButtonData && button.menuBuilder != null) {
      return KeyedSubtree(
        key: ValueKey('viewer-toolbar-menu-${button.action.name}'),
        child: button.menuBuilder!(context, _menu.hide),
      );
    }
    return KurumiPopupMenuItem(
      key: button is ViewerToolbarButtonData
          ? ValueKey('viewer-toolbar-menu-${button.action.name}')
          : null,
      title: Text(button.title),
      icon: button.icon,
      onTap: button.enabled ? button.onTap : null,
    );
  }
}
