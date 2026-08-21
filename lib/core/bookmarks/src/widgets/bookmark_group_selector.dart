// Dart imports:
import 'dart:async';

// Flutter imports:
import 'package:flutter/material.dart';

// Package imports:
import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:material_symbols_icons/symbols.dart';

// Project imports:
import '../../../widgets/widgets.dart';
import '../data/providers.dart';
import '../providers/bookmark_group_providers.dart';
import '../providers/bookmark_provider.dart';
import '../types/bookmark_group.dart';
import 'bookmark_group_name_dialog.dart';

class BookmarkGroupSelector extends ConsumerWidget {
  const BookmarkGroupSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(bookmarkGroupsProvider);
    final selected = ref.watch(selectedBookmarkGroupIdProvider);

    return Container(
      color: Kurumi.themeOf(context).colorScheme.surface,
      padding: const EdgeInsets.only(bottom: 4),
      child: groups.when(
        data: (groups) {
          final activeTarget = ref.watch(activeBookmarkGroupIdProvider);
          if (activeTarget != kUngroupedBookmarkGroupId &&
              !groups.any((group) => group.id == activeTarget)) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) {
                unawaited(
                  setActiveBookmarkGroupId(
                    ref,
                    kUngroupedBookmarkGroupId,
                  ),
                );
              }
            });
          }

          return Row(
            children: [
              Expanded(
                child: ChoiceOptionSelectorList<int>(
                  options: [
                    kUngroupedBookmarkGroupId,
                    ...groups.map((group) => group.id),
                  ],
                  selectedOption: selected,
                  optionLabelBuilder: (value) => switch (value) {
                    null => context.t.bookmark.groups.all,
                    kUngroupedBookmarkGroupId =>
                      context.t.bookmark.groups.ungrouped,
                    final id =>
                      groups
                          .firstWhere(
                            (group) => group.id == id,
                            orElse: () => const BookmarkGroup(
                              id: -2,
                              name: 'Missing group',
                            ),
                          )
                          .name,
                  },
                  onSelected: (value) {
                    ref.read(selectedBookmarkGroupIdProvider.notifier).state =
                        value;
                    if (value != null) {
                      unawaited(setActiveBookmarkGroupId(ref, value));
                    }
                  },
                  sheetTitle: context.t.bookmark.groups.selector,
                  icon: const Icon(Symbols.bookmarks),
                ),
              ),
              BookmarkGroupManagementButton(
                groups: groups,
                selectedGroupId: selected,
              ),
            ],
          );
        },
        error: (error, _) => Text(error.toString()),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class BookmarkGroupManagementButton extends ConsumerWidget {
  const BookmarkGroupManagementButton({
    required this.groups,
    required this.selectedGroupId,
    super.key,
  });

  final List<BookmarkGroup> groups;
  final int? selectedGroupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return KurumiPopupMenuButton(
      icon: const Icon(Symbols.more_vert),
      items: [
        if (_selectedGroup != null) ...[
          KurumiPopupMenuItem(
            title: Text(context.t.bookmark.groups.duplicate),
            onTap: () => _duplicateGroup(context, ref),
          ),
          KurumiPopupMenuItem(
            title: Text(context.t.bookmark.groups.rename),
            onTap: () => _renameGroup(context, ref),
          ),
          KurumiPopupMenuItem(
            title: Text(context.t.bookmark.groups.delete),
            onTap: () => _deleteGroup(context, ref),
          ),
        ],
      ],
    );
  }

  BookmarkGroup? get _selectedGroup {
    if (selectedGroupId == null ||
        selectedGroupId == kUngroupedBookmarkGroupId) {
      return null;
    }

    return groups.firstWhereOrNull((group) => group.id == selectedGroupId);
  }

  Future<void> _duplicateGroup(BuildContext context, WidgetRef ref) async {
    final group = _selectedGroup;
    if (group == null) return;

    try {
      final duplicate = await (await ref.read(
        bookmarkGroupRepoProvider.future,
      )).duplicateGroup(group.id);
      ref.read(selectedBookmarkGroupIdProvider.notifier).state = duplicate.id;
      await setActiveBookmarkGroupId(ref, duplicate.id);
      refreshBookmarkGroupProviders(ref);
    } catch (error) {
      if (!context.mounted) return;
      _showError(context, error);
    }
  }

  Future<void> _renameGroup(BuildContext context, WidgetRef ref) async {
    final group = _selectedGroup;
    if (group == null) return;

    final name = await showBookmarkGroupNameDialog(
      context,
      title: context.t.bookmark.groups.rename,
      saveLabel: context.t.generic.action.save,
      cancelLabel: context.t.generic.action.cancel,
      hintText: context.t.bookmark.groups.name,
      initialName: group.name,
    );
    if (name == null) return;

    try {
      await (await ref.read(bookmarkGroupRepoProvider.future)).renameGroup(
        group.id,
        name,
      );
      refreshBookmarkGroupProviders(ref);
    } catch (error) {
      if (!context.mounted) return;
      _showError(context, error);
    }
  }

  Future<void> _deleteGroup(BuildContext context, WidgetRef ref) async {
    final group = _selectedGroup;
    if (group == null) return;

    final repository = await ref.read(bookmarkGroupRepoProvider.future);
    final preview = await repository.previewDeleteGroup(group.id);
    if (!context.mounted) return;

    if (preview.bookmarkCount > 0) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            context.t.bookmark.groups.delete_group_title(name: group.name),
          ),
          content: Text(
            context.t.bookmark.groups.delete_group_message(
              bookmarks: preview.bookmarkCount,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.t.generic.action.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(context.t.bookmark.groups.delete),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    try {
      final orphanIds = await repository.deleteGroup(group.id);
      if (orphanIds.isNotEmpty) {
        await ref
            .read(bookmarkProvider.notifier)
            .removeBookmarksByIds(
              orphanIds,
            );
      }
      ref.read(selectedBookmarkGroupIdProvider.notifier).state = null;
      await setActiveBookmarkGroupId(ref, kUngroupedBookmarkGroupId);
      refreshBookmarkGroupProviders(ref);
    } catch (error) {
      if (!context.mounted) return;
      _showError(context, error);
    }
  }

  void _showError(BuildContext context, Object error) {
    Kurumi.showErrorToast(context, error.toString());
  }
}
