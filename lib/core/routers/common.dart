// Package imports:
import 'package:go_router/go_router.dart';
import 'package:kurumi/cupertino.dart';
import 'package:kurumi/kurumi.dart';

// Project imports:
import 'routers.dart';

GoRouterPageBuilder genericMobilePageBuilder({
  required Widget Function(BuildContext context, GoRouterState state) builder,
}) =>
    (context, state) => CupertinoPage(
      key: state.pageKey,
      name: state.name,
      child: builder(context, state),
    );

GoRouterPageBuilder largeScreenCompatPageBuilderWithExtra<T>({
  required Widget Function(BuildContext context, GoRouterState state, T extra)
  pageBuilder,
  String? errorScreenMessage,
  bool fullScreen = false,
}) => (context, state) {
  final extra = state.extra is T ? state.extra as T : null;

  if (extra == null) {
    return largeScreenAwarePageBuilder(
      useDialog: !fullScreen,
      builder: (context, state) => LargeScreenAwareInvalidPage(
        useDialog: !fullScreen,
        message: errorScreenMessage ?? 'Invalid parameters',
      ),
    )(context, state);
  }

  final builtPage = pageBuilder(context, state, extra);

  final page = context.isLargeScreen && !fullScreen
      ? KurumiDialog(
          child: builtPage,
        )
      : builtPage;

  return largeScreenAwarePageBuilder(
    useDialog: !fullScreen,
    builder: (context, state) => page,
  )(context, state);
};

GoRouterPageBuilder largeScreenAwarePageBuilder<T>({
  required Widget Function(BuildContext context, GoRouterState state) builder,
  bool useDialog = false,
}) => (context, state) {
  return !context.isLargeScreen
      ? CupertinoPage<T>(
          key: state.pageKey,
          name: state.name,
          child: builder(context, state),
        )
      : useDialog
      ? DialogPage<T>(
          key: state.pageKey,
          name: state.name,
          builder: (context) => builder(context, state),
        )
      : FastFadePage<T>(
          key: state.pageKey,
          name: state.name,
          child: builder(context, state),
        );
};

class FastFadePageRoute<T> extends PageRouteBuilder<T> {
  FastFadePageRoute({
    required this.child,
    super.settings,
  }) : super(
         transitionDuration: const Duration(milliseconds: 100),
         reverseTransitionDuration: const Duration(milliseconds: 100),
         pageBuilder: (context, animation, secondaryAnimation) => child,
         transitionsBuilder: Kurumi.fadeTransitionBuilder(),
       );

  final Widget child;
}

class FastFadePage<T> extends CustomTransitionPage<T> {
  FastFadePage({
    required super.child,
    super.name,
    super.key,
  }) : super(
         transitionsBuilder: Kurumi.fadeTransitionBuilder(),
         transitionDuration: const Duration(milliseconds: 100),
         reverseTransitionDuration: const Duration(milliseconds: 100),
       );
}
