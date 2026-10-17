import 'package:anchor_ui/anchor_ui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../accessibility/behavior.dart';
import '../theme/theme.dart';
import 'back_handler.dart';
import 'focus_ring.dart';

class KurumiContextMenuPageController extends ChangeNotifier {
  WidgetBuilder? _pageBuilder;

  WidgetBuilder? get pageBuilder => _pageBuilder;

  static KurumiContextMenuPageController? maybeOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<_KurumiContextMenuPageScope>()
          ?.controller;

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
  bool updateShouldNotify(_KurumiContextMenuPageScope oldWidget) =>
      controller != oldWidget.controller;
}

class KurumiContextMenu extends StatefulWidget {
  const KurumiContextMenu({
    required this.child,
    required this.menuItemsBuilder,
    super.key,
    this.controller,
    this.triggers = true,
  });

  static const keyboardTriggers = [
    SingleActivator(LogicalKeyboardKey.contextMenu),
    SingleActivator(LogicalKeyboardKey.f10, shift: true),
  ];

  final Widget child;
  final List<Widget> Function(BuildContext context) menuItemsBuilder;
  final KurumiContextMenuController? controller;
  final bool triggers;

  @override
  State<KurumiContextMenu> createState() => _KurumiContextMenuState();
}

class _KurumiContextMenuState extends State<KurumiContextMenu> {
  static _KurumiContextMenuState? _open;
  static final _mounted = <_KurumiContextMenuState>{};

  final _triggerKey = GlobalKey();
  final _controller = AnchorContextMenuController();
  final _menuScope = FocusScopeNode(debugLabel: 'KurumiContextMenu');
  final _pageController = KurumiContextMenuPageController();
  FocusNode? _returnFocus;
  var _openedByKeyboard = false;

  @override
  void initState() {
    super.initState();
    _mounted.add(this);
    widget.controller?._menu = this;
  }

  @override
  void didUpdateWidget(KurumiContextMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    if (oldWidget.controller?._menu == this) oldWidget.controller?._menu = null;
    widget.controller?._menu = this;
  }

  @override
  void dispose() {
    if (widget.controller?._menu == this) widget.controller?._menu = null;
    _mounted.remove(this);
    if (_open == this) _open = null;
    _controller.dispose();
    _menuScope.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _show(Offset position, {required bool byKeyboard}) {
    if (_open case final open? when open != this) open._controller.hide();
    _open = this;
    _returnFocus = FocusManager.instance.primaryFocus;
    _openedByKeyboard = byKeyboard;
    _controller.show(position);
  }

  void _switchTo(Offset position) {
    final viewId = View.of(context).viewId;
    _controller.hide();
    // Resolve after the backdrop is removed so covered/offstage triggers cannot
    // win simply because their layout rectangles contain the pointer.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _open != null) return;
      final result = HitTestResult();
      WidgetsBinding.instance.hitTestInView(result, position, viewId);
      for (final entry in result.path) {
        for (final menu in _mounted) {
          if (menu.widget.triggers &&
              menu._triggerKey.currentContext?.findRenderObject() ==
                  entry.target) {
            menu._show(position, byKeyboard: false);
            return;
          }
        }
      }
    });
  }

  void _showForFocus() {
    final rect = FocusManager.instance.primaryFocus?.rect;
    if (rect == null) return;
    _show(rect.bottomLeft, byKeyboard: true);
  }

  void _handleShow() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_controller.isShowing) return;
      final first = _menuScope.traversalDescendants.firstOrNull;
      if (_openedByKeyboard && first != null) {
        first.requestFocus();
      } else {
        _menuScope.requestFocus();
      }
    });
  }

  void _handleDismiss() {
    _pageController.reset();
    if (_open == this) _open = null;
    if (_menuScope.hasFocus) _returnFocus?.requestFocus();
    _returnFocus = null;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final behavior =
        KurumiTheme.maybeBehaviorOf(context) ?? const KurumiBehaviorData();

    return AnchorContextMenu(
      controller: _controller,
      viewPadding: const EdgeInsets.all(8),
      backdropBuilder: (context) => Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (event) {
          if (event.buttons & kSecondaryButton != 0) _switchTo(event.position);
        },
        child: const SizedBox.expand(),
      ),
      onShow: () {
        behavior.contextMenuShowFeedback?.call();
        _handleShow();
      },
      onDismiss: _handleDismiss,
      menuBuilder: (context) => KurumiDismissible(
        onDismiss: _controller.hide,
        child: FocusScope(
          node: _menuScope,
          child: _KurumiContextMenuPageScope(
            controller: _pageController,
            child: ListenableBuilder(
              listenable: _pageController,
              builder: (context, _) {
                final pageBuilder = _pageController.pageBuilder;
                return Container(
                  padding: EdgeInsets.symmetric(
                    vertical: pageBuilder == null ? 8 : 0,
                    horizontal: 4,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: kElevationToShadow[4],
                    border: Border.all(color: colorScheme.outlineVariant),
                  ),
                  constraints: const BoxConstraints(maxWidth: 240),
                  child:
                      pageBuilder?.call(context) ??
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: widget.menuItemsBuilder(context),
                      ),
                );
              },
            ),
          ),
        ),
      ),
      childBuilder: (context) => ListenableBuilder(
        listenable: _controller,
        builder: (context, child) => KurumiBackHandler(
          enabled: _controller.isShowing,
          onBack: _controller.hide,
          child: child!,
        ),
        child: switch (widget.triggers) {
          false => widget.child,
          true => CallbackShortcuts(
            bindings: {
              for (final trigger in KurumiContextMenu.keyboardTriggers)
                trigger: _showForFocus,
            },
            child: Listener(
              key: _triggerKey,
              behavior: HitTestBehavior.opaque,
              child: KurumiAdaptiveContextMenuGestureTrigger(
                onShow: (position) => _show(position, byKeyboard: false),
                child: widget.child,
              ),
            ),
          ),
        },
      ),
    );
  }
}

class KurumiContextMenuController {
  _KurumiContextMenuState? _menu;

  void showAt(Offset position, {bool fromKeyboard = false}) =>
      _menu?._show(position, byKeyboard: fromKeyboard);

  void hide() => _menu?._controller.hide();
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
    this.onShow,
  });

  final Widget child;
  final ValueChanged<Offset>? onShow;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      // Convertible devices and desktop-class Android builds can use touch and
      // a mouse in the same session. Keep both established entry points active
      // instead of selecting one from the target platform at build time.
      onLongPressStart: (details) {
        (onShow ?? context.showMenu)(details.globalPosition);
      },
      onSecondaryTapDown: (details) {
        (onShow ?? context.showMenu)(details.globalPosition);
      },
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
    this.destructive = false,
  });

  final String title;
  final VoidCallback? onTap;
  final bool enabled;
  final bool hideOnTap;
  final Widget? trailing;
  final bool destructive;

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
          child: KurumiFocusHighlight(
            builder: (context, highlighted) => InkWell(
              hoverColor: enabled ? colorScheme.primary : Colors.transparent,
              focusColor: Colors.transparent,
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
                  color: highlighted ? colorScheme.primary : null,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          color: switch ((enabled, destructive, highlighted)) {
                            (false, _, _) => colorScheme.onSurface.withValues(
                              alpha: 0.38,
                            ),
                            (true, _, true) => colorScheme.onPrimary,
                            (true, true, false) => colorScheme.error,
                            (true, false, false) => colorScheme.onSurface,
                          },
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
      ),
    );
  }
}
