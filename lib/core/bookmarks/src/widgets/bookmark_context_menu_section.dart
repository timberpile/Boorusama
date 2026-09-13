// Flutter imports:
import 'package:flutter/material.dart';

// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:material_symbols_icons/symbols.dart';

// Project imports:
import '../../../configs/config/types.dart';
import '../../../posts/post/types.dart';
import '../data/bookmark_convert.dart';
import '../providers/bookmark_provider.dart';
import '../types/bookmark.dart';
import '../types/bookmark_target.dart';
import 'bookmark_group_label.dart';
import 'bookmark_group_name_dialog.dart';

class BookmarkContextMenuSection extends ConsumerWidget {
  const BookmarkContextMenuSection({
    required this.post,
    required this.config,
    super.key,
  });

  final Post post;
  final BooruConfigAuth config;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(bookmarkProvider).valueOrNull;
    final id = bookmarkIdentityForPost(post, config.booruIdHint);
    final bookmark = library?.bookmarksByUniqueId[id];
    final memberships = library?.membershipsFor(id) ?? const <String>{};
    final container = ProviderScope.containerOf(context, listen: false);
    final navigator = Navigator.of(context, rootNavigator: true);

    return KurumiContextMenuTile(
      title: context.t.post.action.bookmark,
      hideOnTap: false,
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        KurumiContextMenuPageController.maybeOf(context)?.show(
          (pageContext) => _BookmarkContextGroupPage(
            post: post,
            config: config,
            bookmark: bookmark,
            memberships: memberships,
            container: container,
            navigator: navigator,
          ),
        );
      },
    );
  }
}

class _BookmarkContextGroupPage extends StatelessWidget {
  const _BookmarkContextGroupPage({
    required this.post,
    required this.config,
    required this.bookmark,
    required this.memberships,
    required this.container,
    required this.navigator,
  });

  final Post post;
  final BooruConfigAuth config;
  final Bookmark? bookmark;
  final Set<String> memberships;
  final ProviderContainer container;
  final NavigatorState navigator;

  @override
  Widget build(BuildContext context) {
    final library = container.read(bookmarkProvider).valueOrNull;
    final isGrouped = bookmark != null && memberships.isNotEmpty;
    final labels = bookmarkGroupLabels(library?.groups ?? const []);
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.heightOf(context) * .6),
      child: ListView(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        children: [
          KurumiPopupMenuItem(
            icon: const Icon(Icons.arrow_back),
            title: Text(context.t.generic.action.back),
            hideOnTap: false,
            onTap:
                KurumiContextMenuPageController.maybeOf(context)?.reset ??
                () {},
          ),
          const Divider(),
          if (!isGrouped)
            _item(
              context,
              groupId: null,
              name: context.t.bookmark.groups.ungrouped,
              selected: bookmark != null,
            ),
          for (final group in library?.groups ?? const [])
            _item(
              context,
              groupId: group.id,
              name: labels[group.id]!,
              selected: memberships.contains(group.id),
            ),
          const Divider(),
          KurumiPopupMenuItem(
            icon: const Icon(Symbols.create_new_folder),
            title: Text(context.t.bookmark.groups.create_new),
            onTap: () => _afterDismiss(() => _createGroup(navigator.context)),
          ),
        ],
      ),
    );
  }

  Widget _item(
    BuildContext context, {
    required String? groupId,
    required String name,
    required bool selected,
  }) => KurumiPopupMenuItem(
    icon: Icon(
      groupId == null ? Symbols.bookmark : Symbols.bookmarks,
      fill: selected ? 1 : 0,
    ),
    title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
    onTap: () => _afterDismiss(() => _toggle(groupId)),
  );

  void _afterDismiss(Future<void> Function() action) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (navigator.mounted) await action();
    });
  }

  Future<void> _toggle(String? groupId) async {
    final notifier = container.read(bookmarkProvider.notifier);
    try {
      final activated = await notifier.setActiveTarget(
        groupId == null
            ? const BookmarkTarget.ungrouped()
            : BookmarkTarget.group(groupId),
      );
      if (!activated) {
        _error();
        return;
      }
      if (groupId == null) {
        if (bookmark == null) {
          await notifier.addBookmark(
            config,
            post,
            onSuccess: _added,
            onError: _error,
          );
        }
        if (bookmark != null && memberships.isEmpty) {
          await notifier.removeBookmark(
            bookmark!,
            onSuccess: _removed,
            onError: _error,
          );
        }
        return;
      }
      if (bookmark == null) {
        await notifier.addBookmarkToGroup(
          config,
          post,
          groupId,
          onSuccess: _added,
          onError: _error,
        );
      } else if (memberships.contains(groupId)) {
        await notifier.removeFromGroup(
          [bookmark!],
          groupId,
          deleteWhenMembershipBecomesEmpty: true,
          onSuccess: _removed,
          onError: _error,
        );
      } else {
        await notifier.addExistingBookmarkToGroup(
          bookmark!,
          groupId,
          onSuccess: _added,
          onError: _error,
        );
      }
    } catch (_) {
      _error();
    }
  }

  Future<void> _createGroup(BuildContext context) async {
    final name = await showBookmarkGroupNameDialog(
      context,
      title: context.t.bookmark.groups.create,
    );
    if (name == null) return;
    try {
      final notifier = container.read(bookmarkProvider.notifier);
      await notifier.createGroupWithPosts(name, config, [post]);
      _added();
    } catch (_) {
      _error();
    }
  }

  void _added() {
    if (navigator.mounted) {
      Kurumi.showSuccessToast(
        navigator.context,
        navigator.context.t.bookmark.added,
      );
    }
  }

  void _removed() {
    if (navigator.mounted) {
      Kurumi.showSuccessToast(
        navigator.context,
        navigator.context.t.bookmark.removed,
      );
    }
  }

  void _error() {
    if (navigator.mounted) {
      Kurumi.showErrorToast(
        navigator.context,
        navigator.context.t.bookmark.groups.operation_failed,
      );
    }
  }
}
