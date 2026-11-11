import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../router.dart';

/// Content-owned navigation shares the gallery's viewport and scroll lifetime.
class ViewerEntryNavigationHeader extends StatelessWidget {
  const ViewerEntryNavigationHeader({this.actions = const [], super.key});

  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => KurumiSliverAppBar(
    automaticallyImplyLeading: false,
    automaticallyImplyActions: false,
    floating: true,
    snap: true,
    backgroundColor: Kurumi.themeOf(context).colorScheme.surface,
    scrolledUnderElevation: 0,
    toolbarHeight: 56,
    leadingWidth: 56,
    leading: Center(
      child: KurumiCircularIconButton(
        semanticLabel: context.t.generic.action.back,
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        icon: const Padding(
          padding: EdgeInsets.only(left: 8),
          child: Icon(Symbols.arrow_back_ios),
        ),
        onPressed: () async {
          if (!await Navigator.of(context).maybePop() && context.mounted) {
            GoRouter.maybeOf(context)?.go('/');
          }
        },
      ),
    ),
    actions: actions,
  );
}

/// Pending and unavailable content must retain navigation before a grid exists.
class ViewerEntryNavigationStatus extends StatelessWidget {
  const ViewerEntryNavigationStatus({
    required this.child,
    this.actions = const [],
    super.key,
  });

  final Widget child;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    bottom: false,
    child: CustomScrollView(
      slivers: [
        ViewerEntryNavigationHeader(actions: actions),
        SliverFillRemaining(hasScrollBody: false, child: Center(child: child)),
      ],
    ),
  );
}
