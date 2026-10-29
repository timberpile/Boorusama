import 'package:material_ui/material_ui.dart';
import 'package:oktoast/oktoast.dart';

import 'media_query.dart';

void kurumiShowSuccessToast(
  BuildContext context,
  String message, {
  Duration? duration,
  Color? backgroundColor,
  TextStyle? textStyle,
  String? actionLabel,
  VoidCallback? onAction,
}) {
  if (actionLabel == null || onAction == null) {
    showToast(
      message,
      position: ToastPosition.bottom,
      margin: const EdgeInsets.all(100),
      textPadding: const EdgeInsets.all(8),
      backgroundColor: backgroundColor,
      textStyle: textStyle,
      duration: duration,
    );
    return;
  }

  final theme =
      context.findAncestorWidgetOfExactType<OKToast>() ??
      const OKToast(child: SizedBox.shrink());
  final style =
      textStyle ??
      theme.textStyle ??
      const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.normal,
        color: Colors.white,
      );
  final insets = KurumiOverlayInsetsScope.maybeOf(context);
  final liveBottom = insets?.bottomPaddingListenable;
  late final ToastFuture toast;
  var actionTaken = false;
  final content = Container(
    key: const ValueKey('kurumi-action-toast'),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: backgroundColor ?? theme.backgroundColor,
      borderRadius: BorderRadius.circular(theme.radius),
    ),
    child: Material(
      type: MaterialType.transparency,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                message,
                style: style,
                textAlign: theme.textAlign ?? TextAlign.center,
              ),
            ),
          ),
          const SizedBox(width: 12),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: style.color,
              backgroundColor: Colors.white.withValues(alpha: 0.12),
              textStyle: style,
              side: BorderSide.none,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: const Size(48, 48),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: () {
              if (actionTaken) return;
              actionTaken = true;
              toast.dismiss();
              onAction();
            },
            child: Text(actionLabel),
          ),
        ],
      ),
    ),
  );
  Widget padded(double bottom, Widget child) => Padding(
    padding: EdgeInsets.fromLTRB(16, 16, 16, bottom + 16),
    child: child,
  );
  toast = showToastWidget(
    liveBottom != null
        ? ValueListenableBuilder<double>(
            valueListenable: liveBottom,
            child: content,
            builder: (_, bottom, child) => padded(bottom, child!),
          )
        : Builder(
            builder: (overlayContext) => padded(
              insets?.bottomPadding ??
                  MediaQuery.maybeOf(overlayContext)?.padding.bottom ?? 0,
              content,
            ),
          ),
    context: context,
    // OKToast already moves its overlay above the keyboard. Only add the live
    // navigation/system obstruction here, without a second fixed bar offset.
    position: const ToastPosition(align: Alignment.bottomCenter),
    duration: duration,
    handleTouch: true,
    dismissOtherToast: true,
  );
}

void kurumiShowErrorToast(
  BuildContext context,
  String message, {
  Duration? duration,
}) => showToast(
  message,
  position: ToastPosition.bottom,
  margin: const EdgeInsets.symmetric(
    horizontal: 20,
    vertical: 60,
  ),
  textPadding: const EdgeInsets.symmetric(
    horizontal: 8,
    vertical: 4,
  ),
  duration: duration ?? const Duration(seconds: 4),
  backgroundColor: Theme.of(context).colorScheme.error,
  textStyle: TextStyle(
    color: Theme.of(context).colorScheme.onError,
    fontSize: 14,
    fontWeight: FontWeight.w500,
  ),
);

void kurumiShowSimpleSnackBar({
  required BuildContext context,
  required Widget content,
  Duration? duration,
  SnackBarBehavior? behavior,
  SnackBarAction? action,
}) {
  final snackBarBehavior = behavior ?? SnackBarBehavior.floating;
  final snackbar = SnackBar(
    action: action,
    persist: false,
    behavior: snackBarBehavior,
    duration: duration ?? const Duration(seconds: 4),
    elevation: 6,
    width: _calculateSnackBarWidth(context, snackBarBehavior),
    content: content,
  );
  ScaffoldMessenger.of(context).showSnackBar(snackbar);
}

double? _calculateSnackBarWidth(
  BuildContext context,
  SnackBarBehavior behavior,
) {
  if (behavior == SnackBarBehavior.fixed) return null;
  final width = MediaQuery.maybeWidthOf(context) ?? 400;

  return width > 400 ? 400 : width;
}
