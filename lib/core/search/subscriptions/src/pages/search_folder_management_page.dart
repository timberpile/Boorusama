import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../providers/search_subscriptions_notifier.dart';
import '../types/search_organization.dart';
import '../widgets/search_folder_dialog.dart';
import '../widgets/pinned_search_card.dart';

class SearchFolderManagementPage extends ConsumerWidget {
  const SearchFolderManagementPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = context.t.pinned_searches;
    final notifier = ref.read(searchSubscriptionsProvider.notifier);
    return Scaffold(
      appBar: AppBar(
        title: Text(strings.manage_folders),
        actions: [
          IconButton(
            tooltip: strings.create_folder,
            icon: const Icon(Symbols.create_new_folder),
            onPressed: () async {
              final name = await showSearchFolderNameDialog(context);
              if (name != null && context.mounted) {
                await _run(context, () => notifier.createSharedFolder(name));
              }
            },
          ),
        ],
      ),
      body: ref
          .watch(searchSubscriptionsProvider)
          .when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => Center(child: Text(strings.load_failed)),
            data: (state) => ListView(
              children: [
                for (final (index, folder)
                    in state.organization.folders.indexed)
                  ListTile(
                    key: ValueKey(folder.id),
                    leading: const Icon(Symbols.folder),
                    title: Text(folder.name),
                    subtitle: Text(
                      strings.folder_item_count.replaceAll(
                        '{count}',
                        '${folder.searchIds.length}',
                      ),
                    ),
                    trailing: PopupMenuButton<PinnedSearchAction>(
                      onSelected: (action) async {
                        switch (action) {
                          case PinnedSearchAction.rename:
                            final name = await showSearchFolderNameDialog(
                              context,
                              name: folder.name,
                            );
                            if (name != null && context.mounted) {
                              await _run(
                                context,
                                () => notifier.renameSharedFolder(
                                  folder.id,
                                  name,
                                ),
                              );
                            }
                          case PinnedSearchAction.moveUp ||
                              PinnedSearchAction.moveDown:
                            await _run(
                              context,
                              () => notifier.reorderSharedFolders(
                                index,
                                index +
                                    (action == PinnedSearchAction.moveUp
                                        ? -1
                                        : 1),
                              ),
                            );
                          case PinnedSearchAction.delete:
                            await _delete(context, ref, folder);
                          case _:
                            break;
                        }
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: PinnedSearchAction.rename,
                          child: Text(strings.rename),
                        ),
                        PopupMenuItem(
                          value: PinnedSearchAction.moveUp,
                          enabled: index > 0,
                          child: Text(strings.move_up),
                        ),
                        PopupMenuItem(
                          value: PinnedSearchAction.moveDown,
                          enabled:
                              index < state.organization.folders.length - 1,
                          child: Text(strings.move_down),
                        ),
                        PopupMenuItem(
                          value: PinnedSearchAction.delete,
                          child: Text(context.t.generic.action.delete),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
    );
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    SharedSearchFolder folder,
  ) async {
    final strings = context.t.pinned_searches;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strings.delete_title.replaceAll('{name}', folder.name)),
        content: folder.searchIds.isEmpty
            ? null
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    strings.delete_shared_folder_message.replaceAll(
                      '{count}',
                      '${folder.searchIds.length}',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(strings.unpinning_cannot_be_undone),
                ],
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.t.generic.action.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.t.generic.action.delete),
          ),
        ],
      ),
    );
    if ((confirmed ?? false) && context.mounted) {
      await _run(
        context,
        () => ref
            .read(searchSubscriptionsProvider.notifier)
            .deleteSharedFolderAndPins(folder.id),
      );
    }
  }

  Future<void> _run(
    BuildContext context,
    Future<Object?> Function() action,
  ) async {
    try {
      await action();
    } catch (_) {
      if (context.mounted) {
        Kurumi.showErrorToast(
          context,
          context.t.pinned_searches.operation_failed,
        );
      }
    }
  }
}
