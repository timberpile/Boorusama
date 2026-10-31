import 'dart:math';

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

/// Suppresses touch long press while keeping pointer and keyboard entry points.
class KurumiContextMenuPolicy extends InheritedWidget {
  const KurumiContextMenuPolicy({
    required this.touchLongPress,
    required super.child,
    super.key,
  });
  final bool touchLongPress;
  static bool touchLongPressOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<KurumiContextMenuPolicy>()
          ?.touchLongPress ??
      true;
  @override
  bool updateShouldNotify(KurumiContextMenuPolicy oldWidget) =>
      touchLongPress != oldWidget.touchLongPress;
}

class KurumiContextMenu extends StatefulWidget {
  const KurumiContextMenu({
    required this.child,
    required this.menuItemsBuilder,
    super.key,
    this.controller,
    this.triggers = true,
    this.touchLongPress,
  });

  static const keyboardTriggers = [
    SingleActivator(LogicalKeyboardKey.contextMenu),
    SingleActivator(LogicalKeyboardKey.f10, shift: true),
  ];

  final Widget child;
  final List<Widget> Function(BuildContext context) menuItemsBuilder;
  final KurumiContextMenuController? controller;
  final bool triggers;
  final bool? touchLongPress;

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
  LocalHistoryEntry? _historyEntry;
  ModalRoute<dynamic>? _historyRoute;
  FocusNode? _returnFocus;
  var _openedByKeyboard = false;
  var _position = Offset.zero;

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
    _releaseHistory();
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
    _position = position;
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
    // Android must know a root route can handle Back before dispatching it
    // to Dart. A Router BackButtonListener alone does not advertise that.
    final route = ModalRoute.of(context);
    if (_historyEntry == null && route != null && route.isCurrent) {
      late final LocalHistoryEntry entry;
      entry = LocalHistoryEntry(
        impliesAppBarDismissal: false,
        onRemove: () {
          if (_historyEntry != entry) return;
          _historyEntry = null;
          _historyRoute = null;
          _notifyHistoryChanged(route);
          if (mounted) _controller.hide();
        },
      );
      _historyEntry = entry;
      _historyRoute = route;
      route.addLocalHistoryEntry(entry);
      _notifyHistoryChanged(route);
    }
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
    _releaseHistory();
    _pageController.reset();
    if (_open == this) _open = null;
    if (_menuScope.hasFocus) _returnFocus?.requestFocus();
    _returnFocus = null;
  }

  void _releaseHistory() {
    final entry = _historyEntry;
    final route = _historyRoute;
    _historyEntry = null;
    _historyRoute = null;
    entry?.remove();
    if (route != null) _notifyHistoryChanged(route);
  }

  void _notifyHistoryChanged(ModalRoute<dynamic> route) {
    // The pinned SDK does not publish NavigationNotification for local history
    // changes. Advertise complete route capability, including after row disposal.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = route.subtreeContext;
      if (context == null || !context.mounted || !route.isCurrent) return;
      NavigationNotification(
        canHandlePop:
            route.canPop ||
            route.popDisposition == RoutePopDisposition.doNotPop,
      ).dispatch(context);
    });
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
                final padding = MediaQuery.paddingOf(context);
                final keyboard = MediaQuery.viewInsetsOf(context).bottom;
                final top = padding.top + 8;
                final bottom =
                    MediaQuery.heightOf(context) -
                    max(padding.bottom, keyboard) -
                    8;
                // The anchor flips above/below the pointer; it only shifts
                // horizontally, so a long menu must fit one of those sides.
                final availableHeight = max(
                  0.0,
                  min(
                    bottom - top,
                    max(_position.dy - top, bottom - _position.dy),
                  ),
                );
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
                  constraints: BoxConstraints(
                    maxWidth: min(
                      240.0,
                      max(
                        0.0,
                        MediaQuery.widthOf(context) - padding.horizontal - 16,
                      ),
                    ),
                    maxHeight: availableHeight,
                  ),
                  child:
                      pageBuilder?.call(context) ??
                      SingleChildScrollView(
                        primary: false,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: widget.menuItemsBuilder(context),
                        ),
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
                touchLongPress:
                    widget.touchLongPress ??
                    KurumiContextMenuPolicy.touchLongPressOf(context),
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
  const KurumiContextMenuDivider({this.title, super.key});

  final String? title;

  @override
  Widget build(BuildContext context) {
    final title = this.title;
    if (title == null) {
      return const Divider(endIndent: 12, indent: 12, height: 4);
    }
    final theme = Theme.of(context);
    final color = theme.dividerTheme.color ?? theme.colorScheme.outlineVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: LayoutBuilder(
        builder: (context, constraints) => Row(
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: constraints.maxWidth / 2),
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(color: color),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(child: Divider(height: 8, color: color)),
          ],
        ),
      ),
    );
  }
}

class KurumiAdaptiveContextMenuGestureTrigger extends StatelessWidget {
  const KurumiAdaptiveContextMenuGestureTrigger({
    required this.child,
    super.key,
    this.onShow,
    this.touchLongPress = true,
  });

  final Widget child;
  final ValueChanged<Offset>? onShow;
  final bool touchLongPress;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      // Convertible devices and desktop-class Android builds can use touch and
      // a mouse in the same session. Keep both established entry points active
      // instead of selecting one from the target platform at build time.
      onLongPressStart: touchLongPress
          ? (details) {
              (onShow ?? context.showMenu)(details.globalPosition);
            }
          : null,
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
