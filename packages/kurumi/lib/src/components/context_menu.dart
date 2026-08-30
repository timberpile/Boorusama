import 'package:anchor_ui/anchor_ui.dart';
import 'package:flutter/material.dart';

import '../accessibility/behavior.dart';
import '../foundation/platform.dart';
import '../theme/theme.dart';

class KurumiContextMenuPageController extends ChangeNotifier {
  WidgetBuilder? _pageBuilder;

  WidgetBuilder? get pageBuilder => _pageBuilder;

  static KurumiContextMenuPageController? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_KurumiContextMenuPageScope>()
        ?.controller;
  }

  void show(WidgetBuilder pageBuilder) {
    _pageBuilder = pageBuilder;
    notifyListeners();
  }

  void reset() {
    if (_pageBuilder == null) return;
    _pageBuilder = null;
    notifyListeners();
  }
}

class _KurumiContextMenuPageScope extends InheritedWidget {
  const _KurumiContextMenuPageScope({
    required this.controller,
    required super.child,
  });

  final KurumiContextMenuPageController controller;

  @override
  bool updateShouldNotify(_KurumiContextMenuPageScope oldWidget) {
    return controller != oldWidget.controller;
  }
}

class KurumiContextMenu extends StatefulWidget {
  const KurumiContextMenu({
    required this.child,
    required this.menuItemsBuilder,
    super.key,
  });

  final Widget child;
  final List<Widget> Function(BuildContext context) menuItemsBuilder;

  @override
  State<KurumiContextMenu> createState() => _KurumiContextMenuState();
}

class _KurumiContextMenuState extends State<KurumiContextMenu> {
  final _pageController = KurumiContextMenuPageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final behavior =
        KurumiTheme.maybeBehaviorOf(context) ?? const KurumiBehaviorData();

    return AnchorContextMenu(
      viewPadding: const EdgeInsets.all(8),
      backdropBuilder: kurumiIsMobilePlatform()
          ? null
          : (context) => Container(
              color: Colors.transparent,
            ),
      onShow: behavior.contextMenuShowFeedback,
      onDismiss: _pageController.reset,
      menuBuilder: (context) {
        return _KurumiContextMenuPageScope(
          controller: _pageController,
          child: ListenableBuilder(
            listenable: _pageController,
            builder: (context, _) {
              final pageBuilder = _pageController.pageBuilder;
              final content =
                  pageBuilder?.call(context) ??
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: widget.menuItemsBuilder(context),
                  );
              final contentPadding = pageBuilder == null
                  ? const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 4,
                    )
                  : const EdgeInsets.symmetric(horizontal: 4);

              return Container(
                padding: contentPadding,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: kElevationToShadow[4],
                  border: Border.all(
                    color: colorScheme.outlineVariant,
                  ),
                ),
                constraints: const BoxConstraints(
                  maxWidth: 200,
                ),
                child: content,
              );
            },
          ),
        );
      },
      childBuilder: (context) => KurumiAdaptiveContextMenuGestureTrigger(
        child: widget.child,
      ),
    );
  }
}

class KurumiContextMenuDivider extends StatelessWidget {
  const KurumiContextMenuDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return const Divider(
      endIndent: 12,
      indent: 12,
      height: 8,
    );
  }
}

class KurumiAdaptiveContextMenuGestureTrigger extends StatelessWidget {
  const KurumiAdaptiveContextMenuGestureTrigger({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPressStart: kurumiIsMobilePlatform()
          ? (details) {
              context.showMenu(details.globalPosition);
            }
          : null,
      onSecondaryTapDown: !kurumiIsMobilePlatform()
          ? (details) {
              context.showMenu(details.globalPosition);
            }
          : null,
      child: child,
    );
  }
}

class KurumiContextMenuTile extends StatelessWidget {
  const KurumiContextMenuTile({
    required this.title,
    super.key,
    this.onTap,
    this.enabled = true,
    this.hideOnTap = true,
    this.trailing,
  });

  final String title;
  final VoidCallback? onTap;
  final bool enabled;
  final bool hideOnTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final behavior =
        KurumiTheme.maybeBehaviorOf(context) ?? const KurumiBehaviorData();

    void handleTap() {
      if (hideOnTap) {
        context.hideMenu();
      }

      behavior.contextMenuSelectionFeedback?.call();
      onTap?.call();
    }

    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 4,
        ),
        constraints: const BoxConstraints(
          minWidth: 200,
        ),
        child: Semantics(
          button: true,
          enabled: enabled,
          label: title,
          onTap: enabled ? handleTap : null,
          excludeSemantics: true,
          child: InkWell(
            hoverColor: enabled ? colorScheme.primary : Colors.transparent,
            customBorder: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
            onTap: enabled ? handleTap : null,
            child: Container(
              padding: const EdgeInsets.symmetric(
                vertical: 8,
                horizontal: 8,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        color: enabled
                            ? colorScheme.onSurface
                            : colorScheme.onSurface.withValues(alpha: 0.38),
                      ),
                    ),
                  ),
                  if (trailing case final trailing?)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: IgnorePointer(child: trailing),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
