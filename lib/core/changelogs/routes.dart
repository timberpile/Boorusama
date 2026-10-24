// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

// Project imports:
import '../router.dart';
import 'dialog.dart';
import 'page.dart';
import 'providers.dart';

final changelogRoutes = GoRoute(
  path: '/changelog',
  name: 'changelog',
  pageBuilder: largeScreenAwarePageBuilder(
    useDialog: true,
    builder: (context, state) {
      final landscape = context.orientation.isLandscape;

      final page = ChangelogPage(
        dialog: landscape,
      );

      return landscape
          ? KurumiDialog(
              padding: const EdgeInsets.all(8),
              child: page,
            )
          : page;
    },
  ),
);

Future<void> goToChangelogPage(WidgetRef ref) {
  return ref.pushRoute(
    Uri(
      path: '/changelog',
    ).toString(),
  );
}

Future<void> showChangelogDialogIfNeeded(
  BuildContext context,
  WidgetRef ref,
) async {
  final shouldShow = await ref.read(changelogVisibilityNotifierProvider.future);

  if (shouldShow) {
    if (!context.mounted) return;

    final _ = await showDialog(
      context: context,
      routeSettings: const RouteSettings(
        name: 'changelog',
      ),
      builder: (context) => const ChangelogDialog(),
    );

    await ref.read(changelogVisibilityNotifierProvider.notifier).markAsSeen();
  }
}
