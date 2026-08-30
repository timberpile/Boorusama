// Flutter imports:
import 'package:flutter/material.dart';

// Package imports:
import 'package:anchor_ui/anchor_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:material_symbols_icons/symbols.dart';

// Project imports:
import '../../../configs/config/types.dart';
import '../../../posts/post/types.dart';
import '../data/providers.dart';
import '../providers/bookmark_group_providers.dart';
import '../providers/bookmark_provider.dart';
import '../types/bookmark.dart';
import '../types/bookmark_group.dart';
import 'bookmark_group_name_dialog.dart';

/// The local bookmark actions shared by post-thumbnail context menus.
class BookmarkContextMenuSection extends ConsumerWidget {
  const BookmarkContextMenuSection({
    required this.post,
    required this.config,
    super.key,
    this.bookmark,
  });

  final Post post;
  final BooruConfigAuth config;
  final Bookmark? bookmark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(bookmarkProvider).valueOrNull;
    final groups = ref.watch(bookmarkGroupsProvider).valueOrNull ?? const [];
    final bookmarkId =
        bookmark?.uniqueId ??
        BookmarkUniqueId.fromPost(post, config.booruIdHint);
    final isBookmarked =
        state?.bookmarks.contains(bookmarkId) ?? bookmark != null;
    final memberships = state?.memberships[bookmarkId] ?? const <int>{};
    final container = ProviderScope.containerOf(context, listen: false);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const KurumiContextMenuDivider(),
        KurumiContextMenuTile(
          title: context.t.post.action.bookmark,
          hideOnTap: false,
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            final pageController = KurumiContextMenuPageController.maybeOf(
              context,
            );
            if (pageController == null) return;

            final navigator = Navigator.of(context, rootNavigator: true);
            pageController.show(
              (pageContext) => _buildGroupPickerPage(
                pageContext,
                container,
                navigator: navigator,
                groups: groups,
                memberships: memberships,
                isBookmarked: isBookmarked,
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildGroupPickerPage(
    BuildContext context,
    ProviderContainer container, {
    required NavigatorState navigator,
    required List<BookmarkGroup> groups,
    required Set<int> memberships,
    required bool isBookmarked,
  }) {
    final isGroupedBookmark = isBookmarked && memberships.isNotEmpty;
    final pageController = KurumiContextMenuPageController.maybeOf(context);
    final items = <Widget>[];

    items.add(
      KurumiPopupMenuItem(
        icon: const Icon(Icons.arrow_back),
        title: Text(context.t.generic.action.back),
        hideOnTap: false,
        onTap: pageController?.reset ?? () {},
      ),
    );
    items.add(const Divider());

    if (!isGroupedBookmark) {
      items.add(
        KurumiPopupMenuItem(
          icon: Icon(
            Symbols.bookmark,
            fill: isBookmarked && memberships.isEmpty ? 1 : 0,
          ),
          title: Text(context.t.bookmark.groups.ungrouped),
          onTap: () {
            context.hideMenu();
            _toggleGroupAfterDismissal(
              navigator,
              container,
              kUngroupedBookmarkGroupId,
              isBookmarked: isBookmarked,
              memberships: memberships,
            );
          },
        ),
      );
    }

    items.addAll(
      groups.map(
        (group) => KurumiPopupMenuItem(
          icon: Icon(
            Symbols.bookmarks,
            fill: memberships.contains(group.id) ? 1 : 0,
          ),
          title: Text(
            group.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: () {
            context.hideMenu();
            _toggleGroupAfterDismissal(
              navigator,
              container,
              group.id,
              isBookmarked: isBookmarked,
              memberships: memberships,
            );
          },
        ),
      ),
    );

    items.add(const Divider());
    items.add(
      KurumiPopupMenuItem(
        icon: const Icon(Symbols.create_new_folder),
        title: Text(context.t.bookmark.groups.create_new),
        onTap: () {
          context.hideMenu();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (navigator.mounted) {
              _createGroupAndAdd(navigator.context, container);
            }
          });
        },
      ),
    );

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.heightOf(context) * 0.6,
      ),
      child: ListView(
        padding: EdgeInsets.zero,
        shrinkWrap: true,
        children: items,
      ),
    );
  }

  void _toggleGroupAfterDismissal(
    NavigatorState navigator,
    ProviderContainer container,
    int groupId, {
    required bool isBookmarked,
    required Set<int> memberships,
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (navigator.mounted) {
        _toggleGroup(
          navigator.context,
          container,
          groupId,
          isBookmarked: isBookmarked,
          memberships: memberships,
        );
      }
    });
  }

  Future<void> _toggleGroup(
    BuildContext context,
    ProviderContainer container,
    int groupId, {
    required bool isBookmarked,
    required Set<int> memberships,
  }) async {
    final bookmarks = container.read(bookmarkProvider.notifier);
    await setActiveBookmarkGroupIdInContainer(container, groupId);

    if (groupId == kUngroupedBookmarkGroupId) {
      if (isBookmarked && memberships.isNotEmpty) return;

      if (!isBookmarked) {
        await bookmarks.addBookmark(
          config,
          post,
          onSuccess: () => _showSuccess(context, context.t.bookmark.added),
          onError: () =>
              _showError(context, context.t.bookmark.groups.failed_to_add),
        );
      } else if (memberships.isEmpty) {
        await bookmarks.deleteBookmarkWithToast(
          bookmark?.uniqueId ??
              BookmarkUniqueId.fromPost(post, config.booruIdHint),
        );
      }
      return;
    }

    void onError() =>
        _showError(context, context.t.bookmark.groups.failed_to_add_to_group);

    final bookmarkId =
        bookmark?.uniqueId ??
        BookmarkUniqueId.fromPost(post, config.booruIdHint);
    if (memberships.contains(groupId)) {
      await bookmarks.removeFromGroupAndDeleteIfLast(
        bookmarkId,
        groupId,
        onSuccess: () => _showSuccess(context, context.t.bookmark.removed),
        onError: () => _showError(
          context,
          context.t.bookmark.groups.failed_to_remove_from_group,
        ),
      );
    } else if (bookmark case final existing?) {
      await bookmarks.addExistingBookmarkToGroup(
        existing,
        groupId,
        onSuccess: () => _showSuccess(context, context.t.bookmark.added),
        onError: onError,
      );
    } else {
      await bookmarks.addBookmarkToGroup(
        config,
        post,
        groupId,
        onSuccess: () => _showSuccess(context, context.t.bookmark.added),
        onError: onError,
      );
    }
  }

  Future<void> _createGroupAndAdd(
    BuildContext context,
    ProviderContainer container,
  ) async {
    final name = await _showGroupNameDialog(context);
    if (name == null) return;

    try {
      final group = await (await container.read(
        bookmarkGroupRepoProvider.future,
      )).createGroup(name);
      await setActiveBookmarkGroupIdInContainer(container, group.id);

      if (bookmark case final existing?) {
        await container
            .read(bookmarkProvider.notifier)
            .addExistingBookmarkToGroup(
              existing,
              group.id,
              onSuccess: () => _showSuccess(context, context.t.bookmark.added),
            );
      } else {
        await container
            .read(bookmarkProvider.notifier)
            .addBookmarkToGroup(
              config,
              post,
              group.id,
              onSuccess: () => _showSuccess(context, context.t.bookmark.added),
            );
      }
      container.invalidate(bookmarkGroupsProvider);
      container.invalidate(bookmarkProvider);
    } catch (error) {
      if (context.mounted) _showError(context, error.toString());
    }
  }

  Future<String?> _showGroupNameDialog(BuildContext context) {
    return showBookmarkGroupNameDialog(
      context,
      title: context.t.bookmark.groups.create,
      saveLabel: context.t.generic.action.create,
      cancelLabel: context.t.generic.action.cancel,
      hintText: context.t.bookmark.groups.name,
    );
  }

  void _showError(BuildContext context, String message) {
    if (context.mounted) Kurumi.showErrorToast(context, message);
  }

  void _showSuccess(BuildContext context, String message) {
    if (context.mounted) Kurumi.showSuccessToast(context, message);
  }
}
