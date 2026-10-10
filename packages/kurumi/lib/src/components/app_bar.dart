import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'fitted_text.dart';

/// A Material app bar whose text titles fit its existing toolbar bounds.
class KurumiAppBar extends StatelessWidget implements PreferredSizeWidget {
  const KurumiAppBar({
    super.key,
    this.leading,
    this.automaticallyImplyLeading = true,
    this.title,
    this.actions,
    this.automaticallyImplyActions = true,
    this.flexibleSpace,
    this.bottom,
    this.elevation,
    this.scrolledUnderElevation,
    this.shadowColor,
    this.surfaceTintColor,
    this.shape,
    this.backgroundColor,
    this.foregroundColor,
    this.iconTheme,
    this.actionsIconTheme,
    this.primary = true,
    this.centerTitle,
    this.excludeHeaderSemantics = false,
    this.titleSpacing,
    this.leadingWidth,
    this.toolbarTextStyle,
    this.titleTextStyle,
    this.systemOverlayStyle,
    this.forceMaterialTransparency = false,
    this.useDefaultSemanticsOrder = true,
    this.clipBehavior,
    this.actionsPadding,
    this.notificationPredicate = defaultScrollNotificationPredicate,
    this.toolbarOpacity = 1,
    this.bottomOpacity = 1,
    this.toolbarHeight,
    this.animateColor = false,
  });

  final Widget? leading;
  final bool automaticallyImplyLeading;
  final Widget? title;
  final List<Widget>? actions;
  final bool automaticallyImplyActions;
  final Widget? flexibleSpace;
  final PreferredSizeWidget? bottom;
  final double? elevation;
  final double? scrolledUnderElevation;
  final Color? shadowColor;
  final Color? surfaceTintColor;
  final ShapeBorder? shape;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final IconThemeData? iconTheme;
  final IconThemeData? actionsIconTheme;
  final bool primary;
  final bool? centerTitle;
  final bool excludeHeaderSemantics;
  final double? titleSpacing;
  final double? leadingWidth;
  final TextStyle? toolbarTextStyle;
  final TextStyle? titleTextStyle;
  final SystemUiOverlayStyle? systemOverlayStyle;
  final bool forceMaterialTransparency;
  final bool useDefaultSemanticsOrder;
  final Clip? clipBehavior;
  final EdgeInsetsGeometry? actionsPadding;
  final ScrollNotificationPredicate notificationPredicate;
  final double toolbarOpacity;
  final double bottomOpacity;
  final double? toolbarHeight;
  final bool animateColor;

  @override
  Size get preferredSize => AppBar(
    toolbarHeight: toolbarHeight,
    bottom: bottom,
  ).preferredSize;

  @override
  Widget build(BuildContext context) {
    final textScaler =
        KurumiToolbarTitleScope.maybeOf(context)?.textScaler ??
        MediaQuery.textScalerOf(context);
    final height =
        toolbarHeight ??
        AppBarTheme.of(context).toolbarHeight ??
        kToolbarHeight;
    return AppBar(
      leading: leading,
      automaticallyImplyLeading: automaticallyImplyLeading,
      title: title == null
          ? null
          : _ToolbarTitle(
              textScaler: textScaler,
              height: height,
              child: title!,
            ),
      actions: actions,
      automaticallyImplyActions: automaticallyImplyActions,
      flexibleSpace: flexibleSpace,
      bottom: bottom,
      elevation: elevation,
      scrolledUnderElevation: scrolledUnderElevation,
      shadowColor: shadowColor,
      surfaceTintColor: surfaceTintColor,
      shape: shape,
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      iconTheme: iconTheme,
      actionsIconTheme: actionsIconTheme,
      primary: primary,
      centerTitle: centerTitle,
      excludeHeaderSemantics: excludeHeaderSemantics,
      titleSpacing: titleSpacing,
      leadingWidth: leadingWidth,
      toolbarTextStyle: toolbarTextStyle,
      titleTextStyle: titleTextStyle,
      systemOverlayStyle: systemOverlayStyle,
      forceMaterialTransparency: forceMaterialTransparency,
      useDefaultSemanticsOrder: useDefaultSemanticsOrder,
      clipBehavior: clipBehavior,
      actionsPadding: actionsPadding,
      notificationPredicate: notificationPredicate,
      toolbarOpacity: toolbarOpacity,
      bottomOpacity: bottomOpacity,
      toolbarHeight: toolbarHeight,
      animateColor: animateColor,
    );
  }
}

/// A Material app bar whose text titles fit its existing toolbar bounds.
class KurumiSliverAppBar extends StatelessWidget {
  const KurumiSliverAppBar({
    super.key,
    this.leading,
    this.automaticallyImplyLeading = true,
    this.title,
    this.actions,
    this.automaticallyImplyActions = true,
    this.flexibleSpace,
    this.bottom,
    this.elevation,
    this.scrolledUnderElevation,
    this.shadowColor,
    this.surfaceTintColor,
    this.shape,
    this.backgroundColor,
    this.foregroundColor,
    this.iconTheme,
    this.actionsIconTheme,
    this.primary = true,
    this.centerTitle,
    this.excludeHeaderSemantics = false,
    this.titleSpacing,
    this.leadingWidth,
    this.toolbarTextStyle,
    this.titleTextStyle,
    this.systemOverlayStyle,
    this.forceMaterialTransparency = false,
    this.useDefaultSemanticsOrder = true,
    this.clipBehavior,
    this.actionsPadding,
    this.forceElevated = false,
    this.collapsedHeight,
    this.expandedHeight,
    this.floating = false,
    this.pinned = false,
    this.snap = false,
    this.stretch = false,
    this.stretchTriggerOffset = 100,
    this.onStretchTrigger,
    this.toolbarHeight = kToolbarHeight,
  });

  final Widget? leading;
  final bool automaticallyImplyLeading;
  final Widget? title;
  final List<Widget>? actions;
  final bool automaticallyImplyActions;
  final Widget? flexibleSpace;
  final PreferredSizeWidget? bottom;
  final double? elevation;
  final double? scrolledUnderElevation;
  final Color? shadowColor;
  final Color? surfaceTintColor;
  final ShapeBorder? shape;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final IconThemeData? iconTheme;
  final IconThemeData? actionsIconTheme;
  final bool primary;
  final bool? centerTitle;
  final bool excludeHeaderSemantics;
  final double? titleSpacing;
  final double? leadingWidth;
  final TextStyle? toolbarTextStyle;
  final TextStyle? titleTextStyle;
  final SystemUiOverlayStyle? systemOverlayStyle;
  final bool forceMaterialTransparency;
  final bool useDefaultSemanticsOrder;
  final Clip? clipBehavior;
  final EdgeInsetsGeometry? actionsPadding;
  final bool forceElevated;
  final double? collapsedHeight;
  final double? expandedHeight;
  final bool floating;
  final bool pinned;
  final bool snap;
  final bool stretch;
  final double stretchTriggerOffset;
  final AsyncCallback? onStretchTrigger;
  final double toolbarHeight;

  @override
  Widget build(BuildContext context) {
    final textScaler =
        KurumiToolbarTitleScope.maybeOf(context)?.textScaler ??
        MediaQuery.textScalerOf(context);
    final height = toolbarHeight;
    return SliverAppBar(
      leading: leading,
      automaticallyImplyLeading: automaticallyImplyLeading,
      title: title == null
          ? null
          : _ToolbarTitle(
              textScaler: textScaler,
              height: height,
              child: title!,
            ),
      actions: actions,
      automaticallyImplyActions: automaticallyImplyActions,
      flexibleSpace: flexibleSpace,
      bottom: bottom,
      elevation: elevation,
      scrolledUnderElevation: scrolledUnderElevation,
      shadowColor: shadowColor,
      surfaceTintColor: surfaceTintColor,
      shape: shape,
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      iconTheme: iconTheme,
      actionsIconTheme: actionsIconTheme,
      primary: primary,
      centerTitle: centerTitle,
      excludeHeaderSemantics: excludeHeaderSemantics,
      titleSpacing: titleSpacing,
      leadingWidth: leadingWidth,
      toolbarTextStyle: toolbarTextStyle,
      titleTextStyle: titleTextStyle,
      systemOverlayStyle: systemOverlayStyle,
      forceMaterialTransparency: forceMaterialTransparency,
      useDefaultSemanticsOrder: useDefaultSemanticsOrder,
      clipBehavior: clipBehavior,
      actionsPadding: actionsPadding,
      forceElevated: forceElevated,
      collapsedHeight: collapsedHeight,
      expandedHeight: expandedHeight,
      floating: floating,
      pinned: pinned,
      snap: snap,
      stretch: stretch,
      stretchTriggerOffset: stretchTriggerOffset,
      onStretchTrigger: onStretchTrigger,
      toolbarHeight: toolbarHeight,
    );
  }
}

// Forward only the original text scaler. Replacing MediaQuery would restore
// removed status-bar padding inside nested toolbars.
class _ToolbarTitle extends StatelessWidget {
  const _ToolbarTitle({
    required this.textScaler,
    required this.height,
    required this.child,
  });
  final TextScaler textScaler;
  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) => KurumiToolbarTitleScope(
    textScaler: textScaler,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxHeight: height),
      child: switch (child) {
        final Text text => KurumiFittedText(text),
        _ => child,
      },
    ),
  );
}
