// Flutter imports:
import 'package:flutter/material.dart';

// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:material_symbols_icons/symbols.dart';

// Project imports:
import '../../../../bookmarks/providers.dart';
import '../../../../bookmarks/types.dart';
import '../../../../configs/config/providers.dart';
import '../../../../configs/config/types.dart';
import '../../../../themes/theme/types.dart';
import '../../../post/types.dart';

class BookmarkPostButton extends StatelessWidget {
  const BookmarkPostButton({
    required this.post,
    required this.config,
    super.key,
  });

  final Post post;
  final BooruConfigAuth config;

  @override
  Widget build(BuildContext context) => BookmarkGroupToggleButton(
    post: post,
    config: config,
  );
}

class BookmarkPostLikeButtonButton extends ConsumerWidget {
  const BookmarkPostLikeButtonButton({
    required this.post,
    super.key,
  });

  final Post post;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return BookmarkGroupToggleButton(
      post: post,
      config: ref.watchConfigAuth,
      small: true,
    );
  }
}

class BookmarkGroupToggleButton extends ConsumerWidget {
  const BookmarkGroupToggleButton({
    required this.post,
    required this.config,
    super.key,
    this.small = false,
  });

  final Post post;
  final BooruConfigAuth config;
  final bool small;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookmarkStateAsync = ref.watch(bookmarkProvider);
    final state = bookmarkStateAsync.valueOrNull;
    final groups = ref.watch(bookmarkGroupsProvider).valueOrNull ?? const [];
    final target = ref.watch(effectiveActiveBookmarkGroupIdProvider);
    final bookmarkId = BookmarkUniqueId.fromPost(post, config.booruIdHint);
    final isBookmarked = state?.bookmarks.contains(bookmarkId) ?? false;
    final groupIds = state?.memberships[bookmarkId] ?? const <int>{};
    final inTarget = target == kUngroupedBookmarkGroupId
        ? isBookmarked && groupIds.isEmpty
        : groupIds.contains(target);
    final namedGroupCount = groupIds.length;
    final showCount =
        namedGroupCount > 0 &&
        (target == kUngroupedBookmarkGroupId ||
            !groupIds.contains(target) ||
            namedGroupCount > 1);
    final targetName = _targetName(context, target, groups);
    final tooltip = inTarget
        ? context.t.bookmark.groups.remove_from_target(target: targetName)
        : context.t.bookmark.groups.add_to_target(target: targetName);

    Future<void> onTap() async {
      if (bookmarkStateAsync.isLoading) return;

      if (target == kUngroupedBookmarkGroupId) {
        if (!isBookmarked) {
          await ref.bookmarks.addBookmarkWithToast(config, post);
        } else if (groupIds.isEmpty) {
          await ref.bookmarks.removeBookmarkWithToast(bookmarkId);
        } else {
          Kurumi.showErrorToast(
            context,
            context.t.bookmark.groups.grouped_remove_warning,
          );
        }
        return;
      }

      if (inTarget) {
        await ref.bookmarks.removeBookmarkFromGroup(
          bookmarkId,
          target,
          onError: () => Kurumi.showErrorToast(
            context,
            context.t.bookmark.groups.failed_to_remove_from_group,
          ),
        );
      } else if (isBookmarked) {
        await ref.bookmarks.addBookmarkIdToGroup(
          bookmarkId,
          target,
          onError: () => Kurumi.showErrorToast(
            context,
            context.t.bookmark.groups.failed_to_add_to_group,
          ),
        );
      } else {
        await ref.bookmarks.addBookmarkToGroup(
          config,
          post,
          target,
          onError: () => Kurumi.showErrorToast(
            context,
            context.t.bookmark.groups.failed_to_add_to_group,
          ),
        );
      }
    }

    Future<void> onLongPress() => _showGroupPicker(
      context,
      ref,
      target: target,
      groups: groups,
      isBookmarked: isBookmarked,
      groupIds: groupIds,
    );

    final icon = Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(
          Symbols.bookmark,
          fill: inTarget ? 1 : 0,
          color: inTarget
              ? context.colors.upvoteColor
              : context.extendedColorScheme.onSurfaceContainerOverlay,
        ),
        if (showCount)
          Positioned(
            right: -8,
            bottom: -6,
            child: _GroupCountBadge(count: namedGroupCount),
          ),
      ],
    );

    final button = small
        ? Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              onLongPress: onLongPress,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: icon,
              ),
            ),
          )
        : LayoutBuilder(
            builder: (context, constraints) {
              const labelWidth = 56.0;
              const labelHeight = 28.0;
              final showLabel =
                  !constraints.hasBoundedWidth || constraints.maxWidth >= 72;

              return InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: onTap,
                onLongPress: onLongPress,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: showLabel
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 24,
                              height: 24,
                              child: Center(child: icon),
                            ),
                            SizedBox(
                              width: labelWidth,
                              height: labelHeight,
                              child: Text(
                                targetName,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                            ),
                          ],
                        )
                      : SizedBox(
                          width: 24,
                          height: 24,
                          child: Center(child: icon),
                        ),
                ),
              );
            },
          );

    return KurumiTooltip(
      message: tooltip,
      padding: const EdgeInsets.all(8),
      child: button,
    );
  }

  Future<void> _showGroupPicker(
    BuildContext context,
    WidgetRef ref, {
    required int target,
    required List<BookmarkGroup> groups,
    required bool isBookmarked,
    required Set<int> groupIds,
  }) async {
    final availableGroups = groups.isNotEmpty
        ? groups
        : await ref.read(bookmarkGroupsProvider.future);
    if (!context.mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              leading: const Icon(Symbols.bookmark),
              title: Text(context.t.bookmark.groups.ungrouped),
              selected: target == kUngroupedBookmarkGroupId,
              onTap: () {
                Navigator.pop(sheetContext);
                _applyTarget(
                  context,
                  ref,
                  kUngroupedBookmarkGroupId,
                  isBookmarked: isBookmarked,
                  groupIds: groupIds,
                );
              },
            ),
            ...availableGroups.map(
              (group) => ListTile(
                leading: const Icon(Symbols.bookmarks),
                title: Text(group.name),
                selected: group.id == target,
                onTap: () {
                  Navigator.pop(sheetContext);
                  _applyTarget(
                    context,
                    ref,
                    group.id,
                    isBookmarked: isBookmarked,
                    groupIds: groupIds,
                  );
                },
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Symbols.create_new_folder),
              title: Text(context.t.bookmark.groups.create_new),
              onTap: () async {
                Navigator.pop(sheetContext);
                await _createGroupAndAdd(context, ref);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _applyTarget(
    BuildContext context,
    WidgetRef ref,
    int groupId, {
    required bool isBookmarked,
    required Set<int> groupIds,
  }) async {
    await setActiveBookmarkGroupId(ref, groupId);
    final bookmarkId = BookmarkUniqueId.fromPost(post, config.booruIdHint);

    if (groupId == kUngroupedBookmarkGroupId) {
      if (!isBookmarked) {
        await ref.bookmarks.addBookmarkWithToast(config, post);
      } else if (groupIds.isEmpty) {
        await ref.bookmarks.removeBookmarkWithToast(bookmarkId);
      } else {
        if (!context.mounted) return;
        Kurumi.showErrorToast(
          context,
          context.t.bookmark.groups.grouped_remove_warning,
        );
      }
      return;
    }

    if (groupIds.contains(groupId)) {
      await ref.bookmarks.removeBookmarkFromGroup(bookmarkId, groupId);
    } else if (isBookmarked) {
      await ref.bookmarks.addBookmarkIdToGroup(bookmarkId, groupId);
    } else {
      await ref.bookmarks.addBookmarkToGroup(config, post, groupId);
    }
  }

  Future<void> _createGroupAndAdd(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.t.bookmark.groups.create),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: context.t.bookmark.groups.name,
          ),
          onSubmitted: (value) => Navigator.pop(dialogContext, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.t.generic.action.cancel),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: Text(context.t.generic.action.create),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty) return;

    try {
      final group = await (await ref.read(
        bookmarkGroupRepoProvider.future,
      )).createGroup(name);
      await setActiveBookmarkGroupId(ref, group.id);
      await ref.bookmarks.addBookmarkToGroup(config, post, group.id);
      refreshBookmarkGroupProviders(ref);
    } catch (error) {
      if (context.mounted) Kurumi.showErrorToast(context, error.toString());
    }
  }

  String _targetName(
    BuildContext context,
    int target,
    List<BookmarkGroup> groups,
  ) {
    if (target == kUngroupedBookmarkGroupId) {
      return context.t.bookmark.groups.ungrouped;
    }
    for (final group in groups) {
      if (group.id == target) return group.name;
    }
    return context.t.bookmark.groups.ungrouped;
  }
}

class _GroupCountBadge extends StatelessWidget {
  const _GroupCountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
      padding: const EdgeInsets.symmetric(horizontal: 3),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$count',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onPrimary,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

extension BookmarkPostX on WidgetRef {
  void toggleBookmark(Post post) {
    final booruConfig = readConfigAuth;
    read(bookmarkProvider).whenOrNull(
      data: (bookmarkState) {
        final bookmarkId = BookmarkUniqueId.fromPost(
          post,
          booruConfig.booruIdHint,
        );
        final target = read(effectiveActiveBookmarkGroupIdProvider);
        final groupIds = bookmarkState.groupIdsFor(
          post,
          booruConfig.booruIdHint,
        );
        final isBookmarked = bookmarkState.isBookmarked(
          post,
          booruConfig.booruIdHint,
        );

        if (target == kUngroupedBookmarkGroupId) {
          if (!isBookmarked) {
            bookmarks.addBookmarkWithToast(booruConfig, post);
          } else if (groupIds.isEmpty) {
            bookmarks.removeBookmarkWithToast(bookmarkId);
          }
        } else if (groupIds.contains(target)) {
          bookmarks.removeBookmarkFromGroup(bookmarkId, target);
        } else if (isBookmarked) {
          bookmarks.addBookmarkIdToGroup(bookmarkId, target);
        } else {
          bookmarks.addBookmarkToGroup(booruConfig, post, target);
        }
      },
    );
  }
}
