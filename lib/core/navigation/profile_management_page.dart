import '../configs/config/types.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

import '../config_widgets/website_logo.dart';
import '../configs/create/routes.dart';
import '../configs/manage/providers.dart';
import '../configs/manage/src/pages/remove_booru_alert_dialog.dart';
import 'navigation_catalog_provider.dart';

class ProfileManagementPage extends ConsumerWidget {
  const ProfileManagementPage({this.showAppBar = true, super.key});

  final bool showAppBar;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profiles = ref.watch(navigationProfilesProvider);
    final notifier = ref.read(booruConfigProvider.notifier);
    // Match ListTile's themed spacing with the drag handle as a sibling.
    final theme = Theme.of(context);
    final tileTheme = ListTileTheme.of(context);
    final direction = Directionality.of(context);
    final contentPadding =
        (tileTheme.contentPadding ??
                (theme.useMaterial3
                    ? const EdgeInsetsDirectional.only(start: 16, end: 24)
                    : const EdgeInsets.symmetric(horizontal: 16)))
            .resolve(direction);
    final trailingInset = direction == TextDirection.ltr
        ? contentPadding.right
        : contentPadding.left;
    final titleGap =
        (tileTheme.horizontalTitleGap ?? 16) +
        (tileTheme.visualDensity ?? theme.visualDensity).horizontal * 2;
    final bodyPadding = direction == TextDirection.ltr
        ? contentPadding.copyWith(right: titleGap)
        : contentPadding.copyWith(left: titleGap);
    return Scaffold(
      appBar: showAppBar
          ? KurumiAppBar(
              title: Text(context.t.navigation.profiles),
              actions: [
                IconButton(
                  tooltip: context.t.generic.action.add,
                  onPressed: () => goToAddBooruConfigPage(ref),
                  icon: const Icon(Icons.add),
                ),
              ],
            )
          : null,
      body: ReorderableListView.builder(
        // The shell already combines system and navigation insets. Unlike an
        // implicit ListView padding, this must also be explicit for reordering.
        padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
        buildDefaultDragHandles: false,
        header: showAppBar
            ? null
            : ListTile(
                leading: const Icon(Icons.add),
                title: Text(context.t.generic.action.add),
                onTap: () => goToAddBooruConfigPage(ref),
              ),
        itemCount: profiles.length,
        onReorderItem: (oldIndex, newIndex) => notifier.reorder(
          oldIndex,
          newIndex,
          profiles,
        ),
        itemBuilder: (context, index) {
          final profile = profiles[index];
          return Row(
            key: ValueKey(profile.id),
            children: [
              Expanded(
                child: KurumiContextMenu(
                  menuItemsBuilder: (_) => [
                    KurumiContextMenuTile(
                      title: context.t.generic.action.edit,
                      onTap: () =>
                          goToUpdateBooruConfigPage(ref, config: profile),
                    ),
                    KurumiContextMenuTile(
                      title: context.t.generic.action.duplicate,
                      onTap: () => notifier.duplicate(
                        config: profile,
                        onFailure: (message) {
                          if (context.mounted) {
                            Kurumi.showErrorToast(context, message);
                          }
                        },
                      ),
                    ),
                    KurumiContextMenuTile(
                      title: context.t.generic.action.delete,
                      destructive: true,
                      onTap: () => showDialog<void>(
                        context: context,
                        builder: (context) => RemoveBooruConfigAlertDialog(
                          title: context.t.booru.deletion.title(
                            profileName: profile.name,
                          ),
                          description: context.t.booru.deletion.confirmation,
                          onConfirm: () => notifier.delete(
                            profile,
                            onFailure: (message) =>
                                Kurumi.showErrorToast(context, message),
                          ),
                        ),
                      ),
                    ),
                  ],
                  child: ListTile(
                    contentPadding: bodyPadding,
                    leading: SizedBox(
                      width: 32,
                      height: 32,
                      child: ConfigAwareWebsiteLogo.fromConfig(profile.auth),
                    ),
                    title: Text(profile.name),
                    subtitle: Text(
                      Uri.tryParse(profile.url)?.host ?? profile.url,
                    ),
                    onTap: () =>
                        goToUpdateBooruConfigPage(ref, config: profile),
                  ),
                ),
              ),
              // Keep the entire handle outside the context-menu hit region.
              Padding(
                padding: EdgeInsetsDirectional.only(end: trailingInset),
                child: ReorderableDragStartListener(
                  index: index,
                  child: const SizedBox(
                    width: 48,
                    height: 48,
                    child: ColoredBox(
                      color: Colors.transparent,
                      child: Icon(Icons.drag_handle),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
